require('./migrate.coffee')
Ractive = require('ractive')
linkify = require('html-linkify')
YouTubeIframeLoader = require('youtube-iframe')
api = require('./api.coffee')

Ractive.DEBUG = false

loadData = (storageString, defaultValue) ->
  value = JSON.parse(localStorage.getItem(storageString))
  value ?= defaultValue
  return value

saveData = (variable, storageString) ->
  localStorage.setItem(storageString, JSON.stringify(variable))

videos = loadData('videos', [])
videos.sort((a, b) -> if new Date(a.publishedDate) > new Date(b.publishedDate) then 1 else -1)

filter = loadData('video-filter', [])
additionalChannels = loadData('additional-channels', [])

historyValue = loadData('days-into-history', 7)
updateValue = loadData('update-interval', 5)
autoplayValue = loadData('autoplay', false)
watchLaterValue = loadData('watch-later', false)

videoLists = [
  {
    name: 'unwatched'
    filter: (video) ->
      not blocked(video.id) and !video.watched
    reversed: false
  }
  {
    name: 'watched'
    filter: (video) ->
      not blocked(video.id) and video.watched
    reversed: true
  }
  {
    name: 'blocked'
    filter: (video) ->
      blocked(video.id)
    reversed: true
  }
]

blocked = (id) ->
  video = (v for v in ractive.get('videos') when v.id == id)[0]

  if video.playlistId?
    return false
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
  (video for video in (if ractive? then ractive.get('videos') else videos) when list.filter(video)).length

videoPlayerComponent = Ractive.extend({
  template: require('./video-player.jade')
  isolated: false
  oninit: () ->
    player = null
    YouTubeIframeLoader.load((YT) ->
      player = new YT.Player('iframe', {
        events: {
          onStateChange: (event) ->
            if event.data == YT.PlayerState.ENDED

              if ractive.get('currentVideo')?
                videos = ractive.get('videos')
                [video, index] = ([video,
                  index] for video, index in videos when video.id == ractive.get('currentVideo'))[0]

                # If the video has ended, the autoplay option is on, and the video is in the unwatched videos list
                if ractive.get('autoplay') and videoLists[0].filter(video)
                  video.watched = true
                  ractive.update('videos')

                  for i in [index + 1...videos.length]
                    video = videos[i]
                    if videoLists[0].filter(video)
                      ractive.set('currentVideo', video.id)
                      break
              ractive.set('currentVideo', null)
        }
      })
    )
    this.observe('currentVideo', (videoId) ->
      if videoId?
        player.loadVideoById(videoId: videoId)
        ractive.set('videoVisible', true)
      else
        player?.pauseVideo()
    )
    this.on({
      videoToggle: () ->
        ractive.toggle('videoVisible')
    })
})

videoContainerComponent = Ractive.extend({
  isolated: false
  template: require('./video-container.jade')
  oninit: () ->
    videoContainer = this
    this.on({
      mark: () ->
        videoContainer.toggle('watched')
        ractive.update('videos')

      play: () ->
        ractive.set('currentVideo', videoContainer.get('id'))
    })
    this.observe('watched', ((value, oldValue) ->
      if value and oldValue == false # If it's moved from unwatched to watched
        playlistId = this.get('playlistId')
        if playlistId? and ractive.get('watchLater') # If this video is in the watchLater playlist and we're using integration
          remove = () ->
# Clear the playlistId from the video, so we don't try and delete it again
            videoContainer.set('playlistId', null)
          api.deleteFromPlaylist(playlistId).then(remove, remove)
    ))
  data: {
    truncated: true

    paragraphs: (text) ->
      ((linkify(line, {attributes: {target: '_blank'}}) for line in paragraph.split(/\n/)).join('<br>') for paragraph in text.split(/\n{2,}/))
    formatDate: (date) ->
      new Date(date).toLocaleString()
    formatDuration: (date) ->
# Turn the duration string into a list eg. PT3H12M5S -> [null, null, null, 3, 12, 5]
      strings = date.match(/P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/).slice(1, 7)
      # Always make sure we have minutes, so it says 0:27 rather than just 27
      strings[4] = strings[4] or '0'
      for string, i in strings
        if string?
          strings = strings.slice(i)
          break
      # Make every string has 2 digits except from the first one.
      strings = ((if not string? then '00' else if i == 0 or string.length == 2 then string else '0' + string) for string, i in strings)
      strings.join(':')
    blocked: blocked
  }
})

ractive = new Ractive({
  el: '#container'
  template: require('./template.jade')
  magic: true
  data: {
# Saved objects
    videos: videos
    filter: filter
    additionalChannels: additionalChannels
    history: historyValue
    autoplay: autoplayValue
    update: updateValue
    watchLater: watchLaterValue

# Unsaved objects
    videoLists: videoLists
    apiLoaded: false
    loading: false
    showSettings: false
    selectedList: 0
    newChannel: ''
    currentVideo: null
    videoVisible: false

# Methods
    capitalise: (s) ->
      s[0].toUpperCase() + s.slice(1)
    listLength: listLength
  }
  components: {
    Video: videoContainerComponent
    Player: videoPlayerComponent
  }
  transitions: {
    slide: require('ractive-transitions-slide')
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
    loadVideos()

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
ractive.observe('history', ((value) ->
  if value < 0
    value = 0
    ractive.set('history', value)
  saveData(value, 'days-into-history')
  ractive.set('videos', (video for video in ractive.get('videos') when video.playlistId? or
    new Date(video.publishedDate) > (new Date() - 1000 * 60 * 60 * 24 * value)))
), {defer: true})

readDataInterval = null
ractive.observe('update', ((value) ->
  if value < 0
    value = 0
    ractive.set('update', value)
  saveData(value, 'update-interval')
  window.clearInterval(readDataInterval)
  if value > 0
    readDataInterval = window.setInterval((() -> loadVideos()), 1000 * 60 * value)
), {defer: true})

ractive.observe('watchLater', (value) ->
  saveData(value, 'watch-later')
)
scrolls = ({x: 0, y: 0} for list in videoLists)
ractive.observe('selectedList', (value, oldValue) ->
  if oldValue?
    scrolls[oldValue] = {x: window.scrollX, y: window.scrollY}
  window.scrollTo(scrolls[value].x, scrolls[value].y)
  window.setTimeout((() ->
    window.scrollTo(scrolls[value].x, scrolls[value].y)
  ), 0)
)
ractive.observe('additionalChannels', (value) ->
  saveData(value, 'additional-channels')
)
api.loaded.then(() ->
  ractive.set('apiLoaded', true)
  loadVideos()
)
loadVideos = () ->
  videoCallback = (video) ->
# Remove videos that are too old unless they're from the watch later list and sort them
    comparisonDate = new Date() - 1000 * 60 * 60 * 24 * ractive.get('history')
    if video.playlistId? or new Date(video.publishedDate) > comparisonDate
      for v, index in ractive.get('videos')
        if v.id == video.id
          video.watched = (if video.playlistId? then false else v.watched)
          video.playlistId = video.playlistId or v.playlistId
          ractive.set("videos[#{index}]", video)
          return
        if v.publishedDate > video.publishedDate
          ractive.splice('videos', index, 0, video)
          return

      ractive.push('videos', video)

  api.getVideos(videoCallback, (channel.id for channel in ractive.get('additionalChannels')), ractive.get('watchLater'))