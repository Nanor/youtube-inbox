title = ''

class Video
  constructor: (@title, @id, @author, @authorId, publishedDate, @description, @thumbnail) ->
    @publishedDate = new Date(publishedDate)

    description = @description
    @paragraphs = () ->
      (linkifyStr(paragraph) for paragraph in description.split(/\n\n*/))

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
    @save()

  add: (newVideo) ->
    index = @indexOf(newVideo.id)
    if index == -1
# New video
      @videos.push(newVideo)
      @sort()
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
    @videos = (video for video in @videos when video.publishedDate > date)

  sort: () ->
    order = @order
    @videos = @videos.sort((a, b) -> (if a.publishedDate > b.publishedDate then 1 else -1) * order)
    return @

  save: () ->
    localStorage.setItem(@storageString, JSON.stringify(@videos))

  addAllFrom: (sourceList) ->
    @videos = @videos.concat(sourceList.videos)
    @sort()
    @save()
    sourceList.videos = []
    sourceList.save()

class Filter
  constructor: (@storageString) ->
    @contents = JSON.parse(localStorage.getItem(@storageString)) or []
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

    self = @
    @set = (value) ->
      localStorage.setItem(storageString, value)
      if listener?
        listener(self)

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
    thumbnail = null
    for key in Object.keys(videoSnippet.thumbnails)
      value = videoSnippet.thumbnails[key]
      if ((thumbnail == null || thumbnail.width < value.width) && value.url != null)
        thumbnail = value

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

readDataInterval = null
updateInput = new SavedInput('update-interval', 5, (self) ->
  if self.get() > 0
    readDataInterval = window.setInterval(readData, 1000 * 60 * self.get())
  else if self.get() < 0
    self.set(0)
)

videoLists = [unwatchedVideos, watchedVideos, blockedVideos]

fixVideoAspect = (video) ->
  video.style.height = video.clientWidth * 9 / 16 + 'px'

ractive = new Ractive({
  el: '#container'
  template: '#template'
  data: {
    filter: filter
    videoLists: videoLists
    isLong: (id) ->
      el = Ractive.find('#'+id)
      (if el.find('.description').clientHeight >= 240 then 'long' else '')
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

  refresh: () ->
    window.readData()

  done: (event) ->
    watchedVideos.add(unwatchedVideos.remove(event.context.id))
  undone: (event) ->
    unwatchedVideos.add(watchedVideos.remove(event.context.id))
  play: (event) ->
    new YT.Player(event.node, {
      height: event.node.width * 9 / 16,
      width: event.node.width,
      videoId: event.context.id,
      events: {
        'onReady': onPlayerReady,
        'onStateChange': onPlayerStateChange,
      },
    })
  expandedChange: (event) ->
    fixVideoAspect(event.node.nextElementSibling)
  insert: (event) ->
    console.log 'test'

  allDone: () ->
    watchedVideos.addAllFrom(unwatchedVideos)
  allUndone: () ->
    unwatchedVideos.addAllFrom(watchedVideos)
})

ractive.observe('filter', () ->
  filter.update()
)

onPlayerReady = (event) ->
  event.target.playVideo()

onPlayerStateChange = (event) ->
  if event.data == YT.PlayerState.ENDED and autoplayInput.get() and unwatchedVideos.display
    event.target.f.parentElement.nextElementSibling.children[1].click()
    event.target.f.nextElementSibling.nextElementSibling.children[0].click()

  if expandInput.get()
    if event.data == YT.PlayerState.PLAYING
      event.target.f.previousElementSibling.checked = true

    if event.data == YT.PlayerState.ENDED
      event.target.f.previousElementSibling.checked = false
    fixVideoAspect(event.target.f)