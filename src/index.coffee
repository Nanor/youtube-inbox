Ractive.DEBUG = false

class Video
  constructor: (@title, @id, @author, @authorId, publishedDate, @description, @thumbnail, @watched = false) ->
    @publishedDate = new Date(publishedDate)

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

filter = JSON.parse(localStorage.getItem('video-filter')) or []

blocked = (video) ->
  for filterRow in filter
    if video.author == filterRow.channel
      if filterRow.type == 'blacklist'
        for regex in filterRow.regexes.split(',')
          if video.title.match(regex)
            return true
      if filterRow.type == 'whitelist'
        for regex in filterRow.regexes.split(',')
          if video.title.match(regex)
            return false
        return true
  return false

historyInput = JSON.parse(localStorage.getItem('days-into-history')) or 7
autoplayInput = JSON.parse(localStorage.getItem('autoplay')) or false
expandInput = JSON.parse(localStorage.getItem('expand')) or false
updateInput = JSON.parse(localStorage.getItem('update-interval')) or 5
readDataInterval = null

videoList = (Video.fromJson(video) for video in (JSON.parse(localStorage.getItem('videos')) or []))

videoLists = [
  {
    name: 'unwatched'
    filter: (video) ->
      !blocked(video) and !video.watched
    reversed: false
  }
  {
    name: 'watched'
    filter: (video) ->
      !blocked(video) and video.watched
    reversed: true
  }
  {
    name: 'blocked'
    filter: (video) ->
      blocked(video)
    reversed: true
  }
]

saveData = (variable, storageString) ->
  localStorage.setItem(storageString, JSON.stringify(variable))

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
    if video.publishedDate > (new Date() - 1000 * 60 * 60 * 24 * historyInput)
      for v, index in videoList
        if v.id == video.id
          video.watched = v.watched
          videoList[index] = video
          return
      videoList.push(video)

  ractive.set('apiLoaded', window.apiLoaded)
  if window.apiLoaded
    getSubs()

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
        fixVideoAspect(event.node.nextElementSibling)
    })
  data: {
    truncated: true
    expanded: false

    paragraphs: (text) ->
      (linkifyStr(paragraph) for paragraph in text.split(/\n\n*/))
  }
})

ractive = new Ractive({
  el: '#container'
  template: '#template'
  magic: true
  data: {
    filter: filter
    videoLists: videoLists
    videos: videoList
    apiLoaded: window.apiLoaded
    showSettings: false
    selectedList: 0
    historyInput: historyInput
    autoplayInput: autoplayInput
    expandInput: expandInput
    updateInput: updateInput

    capitalise: (s) ->
      s[0].toUpperCase() + s.slice(1)
    listLength: listLength
    sortList: (videos, reversed) ->
      videos.slice().sort((a, b) -> (if a.publishedDate > b.publishedDate then -1 else 1) * (if reversed then 1 else -1))
  }
  components: {
    Video: videoComponent
  }
})

ractive.on({
  filterAdd: () ->
    filter.push({
      channel: ''
      type: 'blacklist'
      regexes: ''
    })
  filterRemove: (event, index) ->
    filter.splice(index, 1)

  refresh: () ->
    window.readData()

  allDone: () ->
    for video in videoList
      video.watched = true
    saveData(videoList, 'videos')
    ractive.update('videoLists')

  allUndone: () ->
    for video in videoList
      video.watched = false
    saveData(videoList, 'videos')
    ractive.update('videoLists')

  login: window.login
})

ractive.observe('filter', () ->
  saveData(filter, 'video-filter')
  ractive.update('videos')
)
title = document.title
ractive.observe('videos', (value) ->
  saveData(value, 'videos')
  videoList = value

  length = listLength(videoLists[0])
  document.title = (if length > 0 then "(#{length}) #{title}" else title)
  ractive.update('videoLists')
)
ractive.observe('autoplayInput', (value) ->
  saveData(value, 'autoplay')
  autoplayInput = value
)
ractive.observe('expandInput', (value) ->
  saveData(value, 'expand')
  expandInput = value
)
ractive.observe('historyInput', (value) ->
  saveData(value, 'days-into-history')
  historyInput = value
  videoList = (video for video in videoList when videoLists[0].filter(video) or
    video.publishedDate > (new Date() - 1000 * 60 * 60 * 24 * historyInput))
  ractive.set('videos', videoList)
)
ractive.observe('updateInput', (value) ->
  saveData(value, 'update-interval')
  updateInput = value
  if value > 0
    readDataInterval = window.setInterval(readData, 1000 * 60 * value)
  else if value < 0
    ractive.set('updateInput', 0)
)

onPlayerReady = (event) ->
  event.target.playVideo()

onPlayerStateChangeBuilder = (id) ->
  (event) ->
    video = (video for video in videoList when video.id == id)[0]
    if event.data == YT.PlayerState.ENDED and autoplayInput and videoLists[0].filter(video)
      event.target.f.parentElement.nextElementSibling.children[1].click()
      event.target.f.nextElementSibling.nextElementSibling.children[0].click()

    if expandInput
      checkBox = event.target.f.previousElementSibling
      if event.data == YT.PlayerState.PLAYING
        checkBox.checked = true
      if event.data == YT.PlayerState.ENDED
        checkBox.checked = false
      fixVideoAspect(event.target.f)