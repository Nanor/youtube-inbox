title = ''

class Video
  constructor: (@title, @id, @author, @authorId, publishedDate, @description, @thumbnail) ->
    @publishedDate = new Date(publishedDate)
    @paragraphs = (linkifyStr(paragraph) for paragraph in @description.split(/\n\n*/))

  @fromJson: (json) ->
    new Video(
      json.title,
      json.id,
      json.author,
      json.authorId,
      json.publishedDate,
      json.description,
      json.thumbnail
    )

class VideoList
  constructor: (@storageString, reversedOrder, @name, blocked, @display) ->
    videoList = JSON.parse(localStorage.getItem(@storageString)) or []
    @videos = (Video.fromJson(video) for video in videoList)
    @order = (if reversedOrder then 1 else -1)
    @sort()
    @deduplicate()
    @save()

  add: (newVideo) ->
    index = @indexOf(newVideo.id)
    if index == -1
# New video
      @videos.push(newVideo)
      @sort()
      @deduplicate()
      @save()
    else
# Video already in list.
      @videos[index] = newVideo
    return @

  remove: (id) ->
    index = @indexOf(id)
    if index != -1
      video = @videos[index]
      @videos.splice(index, 1)
      @sort()
      @save()
      video

  indexOf: (id) ->
    for i in [0...@videos.length]
      if @videos[i].id == id
        return i
    -1

  get: (index) ->
    @videos[index]

  find: (id) ->
    for video in @videos
      if video.id == id
        return video

  length: () ->
    @videos.length

  clearOlderThan: (date) ->
    for video in @videos
      if video.publishedDate < date
        @remove(video.id)

  sort: () ->
    order = @order
    @videos = @videos.sort((a, b) -> (if a.publishedDate > b.publishedDate then 1 else -1) * order)
    return @

  deduplicate: () ->
    temp = @videos
    @videos = []
    for video in temp
      if !@find(video.id)?
        @videos.push(video)

  save: () ->
    localStorage.setItem(@storageString, JSON.stringify(@videos))

  addAllFrom: (sourceList) ->
    @videos = @videos.concat(sourceList.videos)
    @sort()
    @deduplicate()
    @save()
    sourceList.videos = []
    sourceList.save()

class Filter
  constructor: (@storageString) ->
    @contents = JSON.parse(localStorage.getItem(@storageString)) or []

    self = @

    @update()

  update: () ->
    localStorage.setItem(@storageString, JSON.stringify(@contents))
    @filterAll()

  allows: (video) ->
    if video?
      for filter in @contents
        if video.author == filter.channel
          if filter.type == 'blacklist'
            for regex in filter.regexes.split(',')
              if video.title.match(regex)
                return false
          if filter.type == 'whitelist'
            for regex in filter.regexes.split(',')
              if video.title.match(regex)
                return true
            return false
      return true
    return false

  filterAll: () ->
    if unwatchedVideos? and watchedVideos? and blockedVideos?
      for videoList in videoLists
        for video in videoList.videos
          if video?
            if @allows(video) == videoList.blocked
              videoList.remove(video.id)
              if blocked
                unwatchedVideos.add(video)
              else
                blockedVideos.add(video)

class SavedInput
  constructor: (storageString, defaultValue, listener) ->
    @get = () ->
      JSON.parse(localStorage.getItem(storageString))
    @set = (value) ->
      localStorage.setItem(storageString, value)

    @set(JSON.parse(localStorage.getItem(storageString)) or defaultValue)

window.readData = () ->
  watchedVideos.clearOlderThan(new Date() - 1000 * 60 * 60 * 24 * historyInput.get())
  blockedVideos.clearOlderThan(new Date() - 1000 * 60 * 60 * 24 * historyInput.get())

  getSubs = (pageToken) ->
    gapi.client.youtube.subscriptions.list({
      mine: true
      part: 'snippet, contentDetails'
      maxResults: 50
      pageToken: pageToken
    }).execute((response) ->
      loadVideosFromChannel((val.snippet.resourceId.channelId for val in response.items))
      getSubs(response.nextPageToken) if response.nextPageToken?
    )

  loadVideosFromChannel = (channelIds) ->
    gapi.client.youtube.channels.list({
      part: 'contentDetails'
      id: channelIds.join(',')
    }).execute((response) ->
      loadVideosFromPlaylist(val.contentDetails.relatedPlaylists.uploads) for val in response.items
    )

  loadVideosFromPlaylist = (playlistId) ->
    gapi.client.youtube.playlistItems.list({
      part: 'snippet'
      playlistId: playlistId
      maxResults: 50
    }).execute((response) ->
      loadVideo(item.snippet) for item in response.items
    )

  loadVideo = (videoSnippet) ->
    thumbnail = null;
    $.each(videoSnippet.thumbnails, (key, value) ->
      if ((thumbnail == null || thumbnail.width < value.width) && value.url != null)
        thumbnail = value
    );

    video = new Video(
      videoSnippet.title,
      videoSnippet.resourceId.videoId,
      videoSnippet.channelTitle,
      videoSnippet.channelId,
      videoSnippet.publishedAt,
      videoSnippet.description,
      thumbnail.url
    )
    if video.publishedDate > (new Date() - 1000 * 60 * 60 * 24 * historyInput.get())
      if filter.allows(video)
        if watchedVideos.find(video.id)?
          watchedVideos.add(video)
        else
          unwatchedVideos.add(video)
      else
        blockedVideos.add(video)

  getSubs() if window.API_LOADED

filter = new Filter('video-filter')

historyInput = new SavedInput('days-into-history', 28)
autoplayInput = new SavedInput('autoplay', false)
expandInput = new SavedInput('expand', false)

unwatchedVideos = new VideoList("unwatched-videos", true, 'unwatched', false, true)
watchedVideos = new VideoList("watched-videos", false, 'watched', false, false)
blockedVideos = new VideoList("blocked-videos", false, 'blocked', true, false)

videoLists = [unwatchedVideos, watchedVideos, blockedVideos]

readDataInterval = null
updateInput = new SavedInput('update-interval', 5, () ->
  window.clearInterval(readDataInterval)
  if updateInput.get() > 0
    readDataInterval = window.setInterval(readData, 1000 * 60 * updateInput.get())
)
#noinspection CoffeeScriptUnusedLocalSymbols
readDataInterval = window.setInterval(readData, 1000 * 60 * updateInput.get())

ractive = new Ractive({
  el: '#container'
  template: '#template'
  data: {
    filter: filter
    videoLists: videoLists
  }
  computed: {
    historyInput: historyInput
    autoplayInput: autoplayInput
    expandInput: expandInput
    updateInput: updateInput
  }
})

ractive.on({
  filterAdd: () ->
    filter.contents.push({
      channel: ""
      type: "blacklist"
      regexes: ""
    })
  filterRemove: (event, index) ->
    filter.contents.splice(index, 1)
  done: (event, id) ->
    watchedVideos.add(unwatchedVideos.remove(id))
  undone: (event, id) ->
    unwatchedVideos.add(watchedVideos.remove(id))
  play: (event, id) ->
    console.log event
    new YT.Player(event.node, {
      height: event.node.width * 9 / 16,
      width: event.node.width,
      videoId: event.context.id,
      events: {
        'onReady': onPlayerReady,
#        'onStateChange': onPlayerStateChange,
      },
    })
})

ractive.observe('filter', () ->
  filter.update()
)

onPlayerReady = (event) ->
  event.target.playVideo()

$(document).ready(() ->
  $('#refresh').click(window.readData)

  # Click binds
  $('#all-done').click(() ->
    watchedVideos.addAllFrom(unwatchedVideos)
  )
  $('#all-undone').click(() ->
    unwatchedVideos.addAllFrom(watchedVideos)
  )

  onPlayerStateChange = (event) ->
    $video = $(event.target.f).parent()
    if event.data == YT.PlayerState.ENDED and autoplayInput.get() and $('#tab-unwatched').prop('checked')
      $video.next().find('.video').click()
      $video.find('.mark').click()

    $expanded = $video.find('.expanded')
    if event.data == YT.PlayerState.PLAYING and expandInput.get()
      $expanded.prop('checked', true)
      $expanded.change()

    if event.data == YT.PlayerState.ENDED
      $expanded.prop('checked', false)
      $expanded.change()
)