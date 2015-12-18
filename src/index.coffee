title = document.title

DEFAULT = 'default'
REVERSE = 'reverse'
BLOCKED = 'blocked'
PERMANENT = 'permanent'

class Video
  constructor: (@title, @id, @author, @authorId, publishedDate, @description, @thumbnail) ->
    @publishedDate = new Date(publishedDate)

    @truncated = true
    @expanded = false

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
  constructor: (@storageString, @name, options...) ->
    videoList = JSON.parse(localStorage.getItem(@storageString)) or []
    @videos = (Video.fromJson(video) for video in videoList)
    @order = (if REVERSE in options then -1 else 1)
    @display = DEFAULT in options
    @blocked = BLOCKED in options
    @permanent = BLOCKED in options
    @sort()
    @save()

  add: (newVideo) ->
    index = @indexOf(newVideo.id)
    if index == -1
# New video
      @videos.push(newVideo)
      @sort()
    else
# Video already in list.
      @videos[index] = newVideo
    @save()
    return @

  remove: (id) ->
    index = @indexOf(id)
    if index != -1
      video = @videos.splice(index, 1)[0]
      @sort()
      @save()
      video

  indexOf: (id) ->
    for i in [0...@videos.length]
      if @videos[i].id == id
        return i
    -1

  find: (id) ->
    for video in @videos
      if video.id == id
        return video

  length: () ->
    @videos.length

  clearOlderThan: (date) ->
    @videos = (video for video in @videos when video.publishedDate > date)
    @save()

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
  constructor: (@storageString, @videoLists) ->
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
    for videoList in @videoLists
      for video in videoList.videos
        allowed = @allows(video)
        if allowed == videoList.blocked
          videoList.remove(video.id)
          if allowed
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
  for videoList in videoLists
    if not videoList.permanent
      videoList.clearOlderThan(new Date() - 1000 * 60 * 60 * 24 * historyInput.get())

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

  ractive.set('apiLoaded', window.apiLoaded)
  if window.apiLoaded
    getSubs()

unwatchedVideos = new VideoList('unwatched-videos', 'unwatched', DEFAULT, PERMANENT)
watchedVideos = new VideoList('watched-videos', 'watched', REVERSE)
blockedVideos = new VideoList('blocked-videos', 'blocked', REVERSE, BLOCKED)
videoLists = [unwatchedVideos, watchedVideos, blockedVideos]

filter = new Filter('video-filter', videoLists)

historyInput = new SavedInput('days-into-history', 28)
autoplayInput = new SavedInput('autoplay', false)
expandInput = new SavedInput('expand', false)

readDataInterval = null
updateInput = new SavedInput('update-interval', 5, (self) ->
  if self.get() > 0
    readDataInterval = window.setInterval(readData, 1000 * 60 * self.get())
  else if self.get() < 0
    self.set(0)
)

fixVideoAspect = (video) ->
  video.style.height = video.clientWidth * 9 / 16 + 'px'

videoComponent = Ractive.extend({
  isolated: false
  template: '#video-component'
  oninit: () ->
    this.on({
      done: (event, id) ->
        watchedVideos.add(unwatchedVideos.remove(id))
        ractive.update('videoLists')
      undone: (event, id) ->
        unwatchedVideos.add(watchedVideos.remove(id))
        ractive.update('videoLists')
      play: (event, id) ->
        new YT.Player(event.node, {
          height: event.node.width * 9 / 16,
          width: event.node.width,
          videoId: id,
          events: {
            'onReady': onPlayerReady,
            'onStateChange': onPlayerStateChange,
          },
        })
      expandedChange: (event) ->
        fixVideoAspect(event.node.parentNode.parentNode.parentNode.firstChild)
    })
  data: {
    paragraphs: (text) ->
      (linkifyStr(paragraph) for paragraph in text.split(/\n\n*/))
  }
  decorators: {
    video: (node) ->
      if node.children[1].children[2].clientHeight >= 240
        node.children[1].classList.add('long')
      return {
        teardown: (a...) ->
      }
  }
})

ractive = new Ractive({
  el: '#container'
  template: '#template'
  data: {
    filter: filter
    videoLists: videoLists
    apiLoaded: window.apiLoaded

    capitalise: (s) ->
      s[0].toUpperCase() + s.slice(1)
  }
  computed: {
    historyInput: historyInput
    autoplayInput: autoplayInput
    expandInput: expandInput
    updateInput: updateInput
  }
  components: {
    Video: videoComponent
  }
})

ractive.on({
  filterAdd: () ->
    filter.contents.push({
      channel: ''
      type: 'blacklist'
      regexes: ''
    })
  filterRemove: (event, index) ->
    filter.contents.splice(index, 1)

  refresh: () ->
    window.readData()
    ractive.update('videoLists')

  allDone: () ->
    watchedVideos.addAllFrom(unwatchedVideos)
    ractive.update('videoLists')

  allUndone: () ->
    unwatchedVideos.addAllFrom(watchedVideos)
    ractive.update('videoLists')

  login: window.login
})

ractive.observe('filter', () ->
  filter.update()
)
ractive.observe('videoLists[0]', (videoList) ->
  length = videoList.length()
  document.title = (if length > 0 then "(#{length}) #{title}" else title)
)

onPlayerReady = (event) ->
  event.target.playVideo()

onPlayerStateChange = (event) ->
  if event.data == YT.PlayerState.ENDED and autoplayInput.get() and unwatchedVideos.display
    event.target.f.parentElement.nextElementSibling.children[1].click()
    event.target.f.nextElementSibling.nextElementSibling.children[0].click()

  if expandInput.get()
    checkBox = event.target.f.nextElementSibling.nextElementSibling.lastChild.firstChild
    if event.data == YT.PlayerState.PLAYING
      checkBox.checked = true
    if event.data == YT.PlayerState.ENDED
      checkBox.checked = false
    fixVideoAspect(event.target.f)