module.exports = (ractive) ->
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
      loadVideo(item, (video for video in videos when video.id == item.id)[0].playlistId) for item, i in response.items
    )

  loadVideo = (item, playlistId) ->
    videoSnippet = item.snippet
    thumbnail = null
    for key in Object.keys(videoSnippet.thumbnails)
      value = videoSnippet.thumbnails[key]
      if ((thumbnail == null || thumbnail.width < value.width) && value.url != null)
        thumbnail = value

    video = {
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

    if playlistId? or new Date(video.publishedDate) > (new Date() - 1000 * 60 * 60 * 24 * ractive.get('history'))
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
  if ractive.get('additionalChannels')
    loadVideosFromChannel((channel.id for channel in ractive.get('additionalChannels')))
  if ractive.get('watchLater')
    gapi.client.youtube.channels.list({
      part: 'contentDetails'
      mine: true
    }).execute((response) ->
      watchLaterId = response.items[0].contentDetails.relatedPlaylists.watchLater
      loadVideosFromPlaylist(watchLaterId, true)
    )
