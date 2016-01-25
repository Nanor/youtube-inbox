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
expandValue = loadData('expand', false)
watchLaterValue = loadData('watch-later', false)

videoLists = [
  {
    name: 'unwatched'
    filter: (video) ->
      not blocked(video) and !video.watched
    reversed: false
  }
  {
    name: 'watched'
    filter: (video) ->
      not blocked(video) and video.watched
    reversed: true
  }
  {
    name: 'blocked'
    filter: (video) ->
      blocked(video)
    reversed: true
  }
]

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
  (video for video in (if ractive? then ractive.get('videos') else videos) when list.filter(video)).length

videoComponent = Ractive.extend({
  isolated: false
  template: '#video-component'
  oninit: () ->
    videoContainer = this
    this.on({
      mark: () ->
        videoContainer.toggle('watched')
        ractive.update('videos')

      play: (event) ->
        YouTubeIframeLoader.load((YT) ->
          new YT.Player(event.node, {
            height: event.node.width * 9 / 16
            width: event.node.width
            videoId: videoContainer.get('id')
            events: {
              onReady: (event) ->
                event.target.playVideo()
              onStateChange: (event) ->
                video = (v for v in ractive.get('videos') when v.id == videoContainer.get('id'))[0]
                # If the video has ended, the autoplay option is on, and the video is in the unwatched videos list
                if event.data == YT.PlayerState.ENDED and ractive.get('autoplay') and videoLists[0].filter(video)
                  videoContainer.nodes['video-container'].nextElementSibling?.firstChild.click() # Click on the next video to play it if it exists
                  videoContainer.nodes['mark'].click() # Click on the done button for this video
                if ractive.get('expand')
                  checkbox = videoContainer.nodes['expand']
                  # If there's a expand checkbox, and it's playing and not expanded, or ended and expanded
                  if checkbox? and ((event.data == YT.PlayerState.PLAYING and not checkbox.checked) or (event.data == YT.PlayerState.ENDED and checkbox.checked))
                    checkbox.click() # Click the expand checkbox
            }
          })
        )
    })
    this.observe('watched', ((value, oldValue) ->
      if value and oldValue == false # If it's moved from unwatched to watched
        playlistId = this.get('playlistId')
        if playlistId? and ractive.get('watchLater') # If this video is in the watchLater playlist and we're using integration
          api.deleteFromPlaylist(playlistId).then(() ->
            # Clear the playlistId from the video, so we don't try and delete it again
            for video in videos
              if video.playlistId == playlistId
                playlistId = null
          )
    ))
    this.observe('expanded', ((expanded) ->
      container = this.nodes['video-container']
      if container?
        video = container.firstChild
        video.style.height = (video.clientWidth * (if expanded then 0.57 else 0.5797)) + 'px'
    ), {defer: true})
  data: {
    truncated: true
    expanded: false

    paragraphs: (text) ->
      (linkify(paragraph, {attributes: {target: '_blank'}}) for paragraph in text.split(/\n\n*/))
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
  template: '#template'
  magic: true
  data: {
  # Saved objects
    videos: videos
    filter: filter
    additionalChannels: additionalChannels
    history: historyValue
    autoplay: autoplayValue
    expand: expandValue
    update: updateValue
    watchLater: watchLaterValue

  # Unsaved objects
    videoLists: videoLists
    apiLoaded: false
    loading: false
    showSettings: false
    selectedList: 0
    newChannel: ''

  # Methods
    capitalise: (s) ->
      s[0].toUpperCase() + s.slice(1)
    listLength: listLength
  }
  components: {
    Video: videoComponent
  }
  events: {
    tap: require('ractive-events-tap')
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
ractive.observe('expand', (value) ->
  saveData(value, 'expand')
)

ractive.observe('history', ((value) ->
  if value < 0
    value = 0
    ractive.set('history', value)
  saveData(value, 'days-into-history')
  ractive.set('videos', (video for video in ractive.get('videos') when videoLists[0].filter(video) or
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
  if ractive.get('loading')
    return
  ractive.set('loading', true)

  videosCallback = (videos) ->
    # Remove videos that are too old unless they're from the watch later list and sort them
    videos = (video for video in videos when video.playlistId? or new Date(video.publishedDate) > new Date() - 1000 * 60 * 60 * 24 * ractive.get('history'))
    videos.sort((a, b) -> (if new Date(a.publishedDate) > new Date(b.publishedDate) then 1 else -1))
    videosToAdd = []
    for video in videos
      added = false
      for v, index in ractive.get('videos')
        if v.id == video.id
          video.watched = v.watched
          ractive.set("videos[#{index}]", video)
          added = true
          break
      if not added
        videosToAdd.push(video)

    # Add all the video not in the list to the end of the list
    ractive.splice.apply(ractive, ['videos', ractive.get('videos').length, 0].concat(videosToAdd))
    ractive.set('loading', false)

  api.getVideos(videosCallback, (channel.id for channel in ractive.get('additionalChannels')), ractive.get('watchLater'))