require('file?name=[name].[ext]!./index.html')
require('file?name=[name].[ext]!./favicon-vflz7uhzw.ico')

require('./main.sass')
require('font-awesome-webpack')

require('./migrate.coffee')
Ractive = require('ractive')
linkify = require('html-linkify')
YouTubeIframeLoader = require('youtube-iframe')
api = require('./api.coffee')

Ractive.DEBUG = false

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

listLength = (list) ->
  (video for video in ractive.get('videos') when list.filter(video)).length

onPlayerReady = (event) ->
  event.target.playVideo()

onPlayerStateChangeBuilder = (id) ->
  (event) ->
    video = (v for v in ractive.get('videos') when v.id == id)[0]
    if event.data == YT.PlayerState.ENDED and ractive.get('autoplay') and videoLists[0].filter(video)
      event.target.f.parentElement.nextElementSibling?.children[0].click()
      event.target.f.nextElementSibling.nextElementSibling.children[0].click()

    if ractive.get('expand')
      checkBox = event.target.f.nextElementSibling.nextElementSibling.children[2].firstElementChild
      if (event.data == YT.PlayerState.PLAYING and !checkBox.checked) or (event.data == YT.PlayerState.ENDED and checkBox.checked)
        checkBox.click()

videoComponent = Ractive.extend({
  isolated: false
  template: '#video-component'
  oninit: () ->
    this.on({
      mark: (event, id) ->
        [video, index] = ([video, i] for video, i in ractive.get('videos') when video.id == id)[0]
        ractive.toggle("videos[#{index}].watched")

      play: (event, id) ->
        YouTubeIframeLoader.load((YT) ->
          new YT.Player(event.node, {
            height: event.node.width * 9 / 16,
            width: event.node.width,
            videoId: id,
            events: {
              'onReady': onPlayerReady
              'onStateChange': onPlayerStateChangeBuilder(id)
            },
          })
        )
    })
    this.observe('watched', ((value, oldValue) ->
      if value and oldValue == false # If it's moved from unwatched to watched
        playlistId = this.get('playlistId')
        if playlistId? and ractive.get('watchLater') # If this video is in the watchLater playlist and we're using integration
          api.deleteFromPlaylist(playlistId).then(() ->
            for video in videoList
              if video.playlistId == playlistId
                playlistId = null
          )
    ))
    this.observe('expanded', ((expanded) ->
      node = this.fragment.items[0].node
      if node?
        video = node.children[0]
        video.style.height = (video.clientWidth * (if expanded then 0.57 else 0.5797)) + 'px'
    ), {defer: true})
  data: {
    truncated: true
    expanded: false

    paragraphs: (text) ->
      (linkify(paragraph) for paragraph in text.split(/\n\n*/))
    formatDate: (date) ->
      new Date(date).toLocaleString()
    formatDuration: (date) ->
      strings = date.match(/P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/).slice(1, 7)
      for string, i in strings
        if string?
          strings = strings.slice(i)
          break
      strings = ((if !string? then '00' else if i == 0 or string.length == 2 then string else '0' + string) for string, i in strings)
      strings.join(':')
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
    apiLoaded: false

    showSettings: false
    selectedList: 0
    newChannel: ''

    history: JSON.parse(localStorage.getItem('days-into-history')) or 7
    autoplay: JSON.parse(localStorage.getItem('autoplay')) or false
    expand: JSON.parse(localStorage.getItem('expand')) or false
    update: JSON.parse(localStorage.getItem('update-interval')) or 5
    watchLater: JSON.parse(localStorage.getItem('watch-later')) or false

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

  channelAdd: (event) ->
    event.original.preventDefault()
    url = this.get('newChannel')
    name = url.match(/user\/([^/]+)/)?[1]
    id = url.match(/channel\/([^/]+)/)?[1]

    api.getChannel(name, id).then((result) ->
      if result?
        ractive.push('additionalChannels', result)
        ractive.set('newChannel', '')
    )

  channelRemove: (event, index) ->
    additionalChannels.splice(index, 1)

  refresh: () ->
    api.getVideos()

  markAll: (event, done) ->
    for video in ractive.get('videos')
      video.watched = done
    saveData(ractive.get('videos'), 'videos')
    ractive.update('videoLists')
    ractive.update('videos')

  login: () ->
    api.login()
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
    readDataInterval = window.setInterval(api.getVideos, 1000 * 60 * value)
)
ractive.observe('watchLater', (value) ->
  saveData(value, 'watch-later')
  api.setWatchLater(value)
)
ractive.observe('selectedList', () ->
  window.scrollTo(0, 0)
)
ractive.observe('additionalChannels', (value) ->
  saveData(value, 'additional-channels')
  api.setAdditionalChannels(value)
)
api.addApiLoadCallback((loaded) ->
  ractive.set('apiLoaded', loaded)
)
api.addVideosAddCallback((videos) ->
  for video in videos.sort((a, b) -> (if new Date(a.publishedDate) > new Date(b.publishedDate) then 1 else -1))
    added = false
    if playlistId? or new Date(video.publishedDate) > (new Date() - 1000 * 60 * 60 * 24 * ractive.get('history'))
      for v, index in ractive.get('videos')
        if v.id == video.id
          video.watched = v.watched
          ractive.set("videos[#{index}]", video)
          added = true
          break
      #      for v ,index in ractive.get('videos')
      #        if new Date(v.publishedDate) > new Date(video.publishedDate)
      #          ractive.splice('videos', index, 0, video)
      #          return
      if not added
        ractive.push('videos', video)
)
