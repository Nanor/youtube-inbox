class Video
  constructor: (@title, @id, @author, @authorId, publishedDate, @description, @thumbnail, @watched = false) ->
    @publishedDate = new Date(publishedDate)
    @blocked = filter.blocks(this)

  @fromJson: (json) ->
    new Video(
      json.title,
      json.id,
      json.author,
      json.authorId,
      json.publishedDate,
      json.description,
      json.thumbnail
      json.watched
    )

class Filter
  constructor: (@storageString) ->
    @contents = JSON.parse(localStorage.getItem(@storageString)) or []

  update: () ->
    localStorage.setItem(@storageString, JSON.stringify(@contents))
    @filterAll()

  allows: (video) ->
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

  blocks: (video) ->
    !@allows(video)

  filterAll: () ->
    for video in videoList
      video.blocked = @blocks(video)

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
      for v, index in videoList
        if v.id == video.id
          video.watched = v.watched
          videoList[index] = video
          return
      videoList.push(video)

  ractive.set('apiLoaded', window.apiLoaded)
  if window.apiLoaded
    getSubs()

filter = new Filter('video-filter')

videoList = (Video.fromJson(video) for video in (JSON.parse(localStorage.getItem('videos')) or []))
#TODO: Get rid of old videos
saveVideos = () ->
  localStorage.setItem('videos', JSON.stringify(videoList))

videoLists = [
  {
    name: 'unwatched'
    filter: (video) ->
      !video.blocked and !video.watched
    reversed: false
  }
  {
    name: 'watched'
    filter: (video) ->
      !video.blocked and video.watched
    reversed: true
  }
  {
    name: 'blocked'
    filter: (video) ->
      video.blocked
    reversed: true
  }
]

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

listLength = (list) ->
  (video for video in videoList when list.filter(video)).length

videoComponent = Ractive.extend({
  isolated: false
  template: '#video-component'
  oninit: () ->
    this.on({
      mark: (event, id) ->
        video = (video for video in videoList when video.id == id)[0]
        video.watched = !video.watched
        ractive.update('videos')
      play: (event, id) ->
        new YT.Player(event.node, {
          height: event.node.width * 9 / 16,
          width: event.node.width,
          videoId: id,
          events: {
            'onReady': onPlayerReady
            'onStateChange': onPlayerStateChangeBuilder(id)
          },
        })
      expandedChange: (event) ->
        fixVideoAspect(event.node.parentNode.parentNode.parentNode.firstChild)
    })
  data: {
    truncated: true
    expanded: false

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
    videos: videoList
    apiLoaded: window.apiLoaded
    showSettings: false
    selectedList: 0

    capitalise: (s) ->
      s[0].toUpperCase() + s.slice(1)
    listLength: listLength
    sortList: (videos, reversed) ->
      videos.slice().sort((a,b) -> (if a.publishedDate > b.publishedDate then -1 else 1) * (if reversed then 1 else -1))
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
    for video in videoList
      video.watched = true
    ractive.update('videoLists')

  allUndone: () ->
    for video in videoList
      video.watched = false
    ractive.update('videoLists')

  login: window.login
})

ractive.observe('filter', () ->
  filter.update()
  ractive.update('videos')
)
title = document.title
ractive.observe('videos', () ->
  saveVideos()

  length = listLength(videoLists[0])
  document.title = (if length > 0 then "(#{length}) #{title}" else title)
  ractive.update('videoLists')
)

onPlayerReady = (event) ->
  event.target.playVideo()

onPlayerStateChangeBuilder = (id) ->
  (event) ->
    video = (video for video in videoList when video.id == id)[0]
    if event.data == YT.PlayerState.ENDED and autoplayInput.get() and videoLists[0].filter(video)
      event.target.f.parentElement.nextElementSibling.children[0].click()
      event.target.f.nextElementSibling.nextElementSibling.children[0].click()

    #TODO: FIX
    if expandInput.get()
      checkBox = event.target.f.nextElementSibling.nextElementSibling.lastChild.firstChild
      if event.data == YT.PlayerState.PLAYING
        checkBox.checked = true
      if event.data == YT.PlayerState.ENDED
        checkBox.checked = false
      fixVideoAspect(event.target.f)