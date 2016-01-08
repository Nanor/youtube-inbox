OAUTH2_CLIENT_ID = '821457625314-acmfo1dvnlfeea149csscmfasjgq1vsf.apps.googleusercontent.com'
OAUTH2_SCOPES = [
  'https://www.googleapis.com/auth/youtube'
]
loaded = false

window.gapiCallback = () ->
  gapi.auth.init(() ->
    window.setTimeout(checkAuth, 1)
  )
gapi = require('./gapi.js')(gapiCallback)

onApiLoadCallbacks = []
addApiLoadCallback = (callback) ->
  onApiLoadCallbacks.push(callback)
apiLoaded = (value) ->
  loaded = value
  for callback in onApiLoadCallbacks
    callback(value)

onVideosAddCallbacks = []
addVideosAddCallback = (callback) ->
  onVideosAddCallbacks.push(callback)
addVideos = (videos) ->
  for callback in onVideosAddCallbacks
    callback(videos)

watchLater = false
setWatchLater = (value) ->
  watchLater = value

additionalChannels = []
setAdditionalChannels = (value) ->
  additionalChannels = value

checkAuth = () ->
  gapi.auth.authorize({
    client_id: OAUTH2_CLIENT_ID,
    scope: OAUTH2_SCOPES,
    immediate: true,
    cookie_policy: 'single_host_origin',
  }, handleAuthResult)

login = () ->
  gapi.auth.authorize({
    client_id: OAUTH2_CLIENT_ID,
    scope: OAUTH2_SCOPES,
    immediate: false,
    cookie_policy: 'single_host_origin',
  }, handleAuthResult)

handleAuthResult = (authResult) ->
  if authResult and !authResult.error
    gapi.client.load('youtube', 'v3', () ->
      apiLoaded(true)
      getVideos()
    )

getVideos = () ->
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
      loadVideosFromPlaylist(val.contentDetails.relatedPlaylists.uploads, false) for val in response.items
    )

  loadVideosFromPlaylist = (playlistId, watchLater) ->
    gapi.client.youtube.playlistItems.list({
      part: 'contentDetails'
      playlistId: playlistId
      maxResults: 50
    }).execute((response) ->
      loadVideosById(({
        id: item.contentDetails.videoId,
        playlistId: (if watchLater then item.id else null)
      } for item in response.items))
    )

  loadVideosById = (videos) ->
    gapi.client.youtube.videos.list({
      part: 'snippet,contentDetails'
      id: (video.id for video in videos).join(',')
      maxResults: 50
    }).execute((response) ->
      addVideos((loadVideo(item, (video for video in videos when video.id == item.id)[0].playlistId)) for item, i in response.items)
    )

  loadVideo = (item, playlistId) ->
    videoSnippet = item.snippet
    thumbnail = null
    for key in Object.keys(videoSnippet.thumbnails)
      value = videoSnippet.thumbnails[key]
      if ((thumbnail == null || thumbnail.width < value.width) && value.url != null)
        thumbnail = value

    return {
      title: videoSnippet.title
      id: item.id
      author: videoSnippet.channelTitle
      authorId: videoSnippet.channelId
      publishedDate: videoSnippet.publishedAt
      description: videoSnippet.description
      thumbnail: thumbnail.url
      duration: item.contentDetails.duration
      watched: false
      playlistId: playlistId
    }

  if loaded
    getSubs()
    if additionalChannels
      loadVideosFromChannel((channel.id for channel in additionalChannels))
    if watchLater
      gapi.client.youtube.channels.list({
        part: 'contentDetails'
        mine: true
      }).execute((response) ->
        watchLaterId = response.items[0].contentDetails.relatedPlaylists.watchLater
        loadVideosFromPlaylist(watchLaterId, true)
      )

deleteFromPlaylist = (playlistId) ->
  gapi.client.youtube.playlistItems.delete({
    id: playlistId
  })

getChannel = (name, id) ->
  gapi.client.youtube.channels.list({
    part: 'snippet'
    forUsername: name
    id: id
  }).then(((response) ->
      item = response.result.items?[0]
      if item?
        return {
          name: item.snippet.title
          id: item.id
        }),
    (() ->
      return null
    )
  )

module.exports = {
  login: login
  getVideos: getVideos
  deleteFromPlaylist: deleteFromPlaylist
  getChannel: getChannel
  addApiLoadCallback: addApiLoadCallback
  addVideosAddCallback: addVideosAddCallback
  setWatchLater: setWatchLater
  setAdditionalChannels: setAdditionalChannels
}