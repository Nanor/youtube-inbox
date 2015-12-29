Ractive.DEBUG = false
VERSION = 1

current_version = JSON.parse(localStorage.getItem('version')) or 0
if current_version != VERSION
  localStorage.setItem('video-filter', null)
  localStorage.setItem('days-into-history', null)
  localStorage.setItem('autoplay', null)
  localStorage.setItem('expand', null)
  localStorage.setItem('update-interval', null)
  localStorage.setItem('videos', null)
localStorage.setItem('version', VERSION)

filter = JSON.parse(localStorage.getItem('video-filter')) or []

videoList = JSON.parse(localStorage.getItem('videos')) or []
videoList.sort((a, b) -> if new Date(a.publishedDate) > new Date(b.publishedDate) then 1 else -1)

additionalChannels = JSON.parse(localStorage.getItem('additional-channels')) or []

readDataInterval = null

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

fixVideoAspect = (video) ->
  video.style.height = video.clientWidth * 9 / 16 + 'px'

listLength = (list) ->
  (video for video in ractive.get('videos') when list.filter(video)).length

window.readData = () ->
  getSubs = (pageToken) ->
    gapi.client.youtube.subscriptions.list({
      mine: true
      part: 'snippet'
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

    video = {
      title: videoSnippet.title
      id: videoSnippet.resourceId.videoId
      author: videoSnippet.channelTitle
      authorId: videoSnippet.channelId
      publishedDate: videoSnippet.publishedAt
      description: videoSnippet.description
      thumbnail: thumbnail.url
      watched: false
    }

    if new Date(video.publishedDate) > (new Date() - 1000 * 60 * 60 * 24 * ractive.get('history'))
      for v, index in ractive.get('videos')
        if v.id == video.id
          video.watched = v.watched
          ractive.set("videos[#{index}]", video)
          return
#      for v ,index in ractive.get('videos')
#        if new Date(v.publishedDate) > new Date(video.publishedDate)
#          console.log 'splice'
#          ractive.splice('videos', index, 0, video)
#          return
      ractive.push('videos', video)

  ractive.set('apiLoaded', window.apiLoaded)
  if window.apiLoaded
    getSubs()
  loadVideosFromChannel((channel.id for channel in ractive.get('additionalChannels')))

onPlayerReady = (event) ->
  event.target.playVideo()

onPlayerStateChangeBuilder = (id) ->
  (event) ->
    video = (video for video in ractive.get('videos') when video.id == id)[0]
    if event.data == YT.PlayerState.ENDED and ractive.get('autoplay') and videoLists[0].filter(video)
      event.target.f.parentElement.nextElementSibling?.children[1].click()
      event.target.f.nextElementSibling.nextElementSibling.children[0].click()

    if ractive.get('expand')
      checkBox = event.target.f.previousElementSibling
      if event.data == YT.PlayerState.PLAYING
        checkBox.checked = true
      if event.data == YT.PlayerState.ENDED
        checkBox.checked = false
    fixVideoAspect(event.target.f)

videoComponent = Ractive.extend({
  isolated: false
  template: '#video-component'
  oninit: () ->
    this.on({
      mark: (event, id) ->
        index = (i for video, i in ractive.get('videos') when video.id == id)[0]
        ractive.toggle("videos[#{index}].watched")
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
    formatDate: (date) ->
      new Date(date).toLocaleString()
    blocked: blocked
  }
})

ractive = new Ractive({
  el: '#container'
  template: '#template'
  data: {
    filter: filter
    videoLists: videoLists
    videos: videoList
    additionalChannels: additionalChannels
    apiLoaded: window.apiLoaded

    showSettings: false
    selectedList: 0
    newChannel: ''

    history: JSON.parse(localStorage.getItem('days-into-history')) or 7
    autoplay: JSON.parse(localStorage.getItem('autoplay')) or false
    expand: JSON.parse(localStorage.getItem('expand')) or false
    update: JSON.parse(localStorage.getItem('update-interval')) or 5

    capitalise: (s) ->
      s[0].toUpperCase() + s.slice(1)
    listLength: listLength
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

  channelAdd: (event, url) ->
    name = null
    id = null

    m = url.match(/user\/([^/]+)/)
    if m
      name = m[1]
    m = url.match(/channel\/([^/]+)/)
    if m
      id = m[1]

    ractive.set('newChannel', '')

    gapi.client.youtube.channels.list({
      part: 'snippet'
      forUsername: name
      id: id
    }).execute((response) ->
      item = response.items?[0]
      if item
        ractive.push('additionalChannels', {
          name: item.snippet.title
          id: item.id
        })
    )

  channelRemove: (event, index) ->
    additionalChannels.splice(index, 1)

  refresh: () ->
    window.readData()

  markAll: (event, done) ->
    for video in ractive.get('videos')
      video.watched = done
    saveData(ractive.get('videos'), 'videos')
    ractive.update('videoLists')
    ractive.update('videos')

  login: window.login
})

ractive.observe('filter', () ->
  saveData(filter, 'video-filter')
  ractive.update('videos')
)
title = document.title
ractive.observe('videos', (value) ->
  saveData(value, 'videos')

  length = listLength(videoLists[0])
  document.title = (if length > 0 then "(#{length}) #{title}" else title)
  ractive.update('videoLists')
)
ractive.observe('autoplay', (value) ->
  saveData(value, 'autoplay')
)
ractive.observe('expand', (value) ->
  saveData(value, 'expand')
)
ractive.observe('history', (value) ->
  saveData(value, 'days-into-history')
  ractive.set('videos', (video for video in ractive.get('videos') when videoLists[0].filter(video) or
    new Date(video.publishedDate) > (new Date() - 1000 * 60 * 60 * 24 * value)))
)
ractive.observe('update', (value) ->
  saveData(value, 'update-interval')
  if value > 0
    readDataInterval = window.setInterval(readData, 1000 * 60 * value)
)
ractive.observe('selectedList', () ->
  window.scrollTo(0, 0)
)
ractive.observe('additionalChannels', (value) ->
  saveData(value, 'additional-channels')
)