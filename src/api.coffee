OAUTH2_CLIENT_ID = '821457625314-acmfo1dvnlfeea149csscmfasjgq1vsf.apps.googleusercontent.com'
OAUTH2_SCOPES = [
  'https://www.googleapis.com/auth/youtube'
]

gapiCallback = () ->
  gapi.auth.init(() ->
    window.setTimeout(checkAuth, 1)
  )
gapi = require('./gapi.js')(gapiCallback)

loaded = false
apiLoaded = null
loadedPromise = new Promise((resolve) ->
  apiLoaded = () ->
    loaded = true
    resolve()
)

authorize = (displayPopup) ->
  gapi.auth.authorize({
    client_id: OAUTH2_CLIENT_ID
    scope: OAUTH2_SCOPES
    immediate: not displayPopup
    cookie_policy: 'single_host_origin'
  }).then((authResult) ->
    if authResult and !authResult.error
      gapi.client.load('youtube', 'v3', () ->
        apiLoaded()
      )
  )

checkAuth = () ->
  authorize(false)

login = () ->
  authorize(true)

getVideos = (additionalChannels, watchLater) ->
  if loaded
    videos = []
    channelIds = (channel.id for channel in additionalChannels)

    loadVideo = (item, playlistId) ->
      videoSnippet = item.snippet
      thumbnails = (videoSnippet.thumbnails[key] for key in Object.keys(videoSnippet.thumbnails))
      thumbnail = thumbnails.reduce((a, b) -> if a.width > b.width then a else b)

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

    subPromise = (pageToken) ->
      gapi.client.youtube.subscriptions.list({
        mine: true
        part: 'snippet'
        maxResults: 50
        pageToken: pageToken
      }).then((response) ->
        ids = (channel.snippet.resourceId.channelId for channel in response.result.items)
        channelIds = channelIds.concat(ids)
        nextPageToken = response.result.nextPageToken
        if nextPageToken?
          return subPromise(nextPageToken)
        else
          return channelIds
      )
    playlistPromise = (playlistId, watchLater) ->
      playlistIds = {}
      gapi.client.youtube.playlistItems.list({
        part: 'contentDetails'
        playlistId: playlistId
        maxResults: 50
      }).then((response) ->
        if watchLater
          for item in response.result.items
            playlistIds[item.contentDetails.videoId] = item.id
        gapi.client.youtube.videos.list({
          part: 'snippet,contentDetails'
          id: (item.contentDetails.videoId for item in response.result.items).join(',')
          maxResults: 50
        })
      ).then((response) ->
        videos = videos.concat(loadVideo(video, playlistIds[video.id]) for video in response.result.items)
      )
    Promise.all([
      subPromise().then((channelIds) ->
        slice = 50
        Promise.all((
          gapi.client.youtube.channels.list({
            part: 'contentDetails'
            id: channelIds.slice(n, n + slice).join(',')
          }).then((response) ->
            Promise.all((
              for item in response.result.items
                playlistId = item.contentDetails.relatedPlaylists.uploads
                playlistPromise(playlistId, false)
            ))
          ) for n in [0...channelIds.length] by slice))
      ),
      if watchLater
        gapi.client.youtube.channels.list({
          part: 'contentDetails'
          mine: true
        }).then((response) ->
          playlistPromise(response.result.items[0].contentDetails.relatedPlaylists.watchLater, true)
        )
    ]).then(() ->
      return videos
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
  loaded: loadedPromise
}