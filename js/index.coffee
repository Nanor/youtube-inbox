  class Video
    constructor: (@title, @link, @author, @authorId, @publishedDate, @description, @thumbnail) ->

  class VideoList
    constructor: (@storageString, reversed = false) ->
      @videos = JSON.parse(localStorage.getItem(@storageString)) or []
      @order = if reversed then 1 else -1

    add: (newVideo) ->
      for video in @videos
        if video.link == newVideo.link
          return
      @videos.push(newVideo)
      @videos.sort((a, b) -> (if a.publishedDate > b.publishedDate then -1 else 1) * @order)

    remove: (id) ->
      @videos = (video for video in @videos when video.link != id)

    clearOlderThan: (date) ->
      @videos = (video for video in @videos when video.publishedDate < date)

    indexOf: (id) ->
      ids = (video.link for video in @videos)
      ids.indexOf(id)

    get: (index) ->
      @videos[index]

    find: (id) ->
      for video in @videos
        if video.link == id
          return video

    length: () ->
      @videos.length

    save: () ->
      localStorage.setItem(@storageString, JSON.stringify(@videos))

  class SavedInput
    constructor: (selector, storageString, defaultValue, listener) ->
      value = localStorage.getItem(storageString) or defaultValue
      localStorage.setItem(storageString, value)
      $(selector).val(value)
      $(selector).change((e) ->
        localStorage.setItem(storageString, $(selector).val())
        listener(e) if listener?
      )
      @value = (value) ->
        if value?
          localStorage.setItem(storageString, value)
          $(selector).val(value)
        localStorage.getItem(storageString)

  class SavedCheckbox
    constructor: (selector, storageString, defaultValue, listener) ->
      value = localStorage.getItem(storageString) or defaultValue
      localStorage.setItem(storageString, value)
      $(selector).prop('checked', value)
      $(selector).change((e) ->
        localStorage.setItem(storageString, $(selector).prop('checked'))
        listener(e) if listener?
      )
      @value = (value) ->
        if value?
          localStorage.setItem(storageString, value)
          $(selector).prop('checked', value)
        localStorage.getItem(storageString)

  $(document).ready(() ->
    historyInput = new SavedInput('#history-length', 'days-into-history', 28)
    title = $('title').text()
    watchedVideos = new VideoList("watched-videos", false)
    unwatchedVideos = new VideoList("unwatched-videos", true)

    window.readData = () ->
      watchedVideos.clearOlderThan(new Date() - 1000 * 60 * 60 * 24 * historyInput.value())

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
        thumbnail = null;
        $.each(videoSnippet.thumbnails, (key, value) ->
          if ((thumbnail == null || thumbnail.width < value.width) && value.url != null)
            thumbnail = value
        );

        video = new Video(
          videoSnippet.title,
          videoSnippet.resourceId.videoId,
          videoSnippet.channelTitle,
          videoSnippet.channelId,
          videoSnippet.publishedAt,
          videoSnippet.description,
          thumbnail.url
        )
        if Date.parse(video.publishedDate) > (new Date() - 1000 * 60 * 60 * 24 * historyInput.value())
          if watchedVideos.indexOf(video.link) == -1
            unwatchedVideos.add(video)

        refreshScreen()

      getSubs() if window.API_LOADED

    addVideoToDom = (element, video, index) ->
      isUnwatchedVideo = unwatchedVideos.indexOf(video.link) != -1

      description = $('<div/>', {class: "description"})
      video.description.split(/\n(?:\n)+/).forEach((paragraph) ->
        description.append($('<p>' + paragraph.replace(/\n/g, '<br>') + '</p>'))
      )
      description.find('p').linkify({target: "_blank"})

      `var videoContainer = $('<div/>', {class: 'video-container', id: video.link})
          .append($('<input/>', {type: 'checkbox', class: 'expanded', id: 'expand' + video.link}))
          .append($('<div/>', {class: "video"})
              .append($('<div/>', {class: "thumbnail"})
                  .append($('<p/>', {text: video.title}))
                  .append($('<img/>', {src: video.thumbnail}))
                  .append($('<i/>', {class: 'fa fa-play fa-3x'}))))
          .append($('<div/>', {class: 'video-info'})
              .append($('<div/>', {class: 'author'})
                  .append($('<a/>', {
                      href: 'http://www.youtube.com/channel/' + video.authorId,
                      target: "_blank",
                      text: 'by ' + video.author
                  })))
              .append($('<div/>', {
                  class: 'upload-date',
                  text: 'uploaded ' + (new Date(video.publishedDate)).toLocaleString()
              }))
              .append($('<input/>', {type: 'checkbox', class: 'truncated', id: 'trunc' + video.link, 'checked': true}))
              .append(description)
              .append($('<label/>', {for: 'trunc' + video.link})
                  .append($('<span/>', {class: 'read-more', text: 'Read more'}))
                  .append($('<span/>', {class: 'read-less', text: 'Read less'}))))
          .append($('<div/>', {class: 'side-buttons'})
              .append($('<button/>', {
                  class: 'mark btn btn-default',
                  title: "Mark as " + (isUnwatchedVideo ? 'watched' : 'unwatched'),
              })
                  .append($('<i/>', {class: 'fa fa-' + (isUnwatchedVideo ? "check" : "remove") + ' fa-3x'})))
              .append($('<a/>', {
                  class: 'youtube-watch btn btn-default',
                  title: "Watch on YouTube",
                  href: "https://www.youtube.com/watch?v=" + video.link,
                  target: "_blank"
              })
                  .append($('<i/>', {class: 'fa fa-youtube fa-3x'})))
              .append($('<label/>', {for: 'expand' + video.link})
                  .append($('<div/>', {class: 'expand-player btn btn-default', title: "Expand Video"})
                      .append($('<i/>', {class: 'fa fa-expand fa-3x'})))
                  .append($('<div/>', {class: 'compress-player btn btn-default', title: "Compress Video"})
                      .append($('<i/>', {class: 'fa fa-compress fa-3x'})))));`
      $('.expanded').change(() ->
        video = $(this).next()
        video.height(video.width() * 9 / 16)
      )

      if (index == 0)
        element.prepend(videoContainer)
      else if (index > $(element).children().length)
        element.append(videoContainer);
      else
        $(element).children(':nth-child(' + index + ')').after(videoContainer)

      if (videoContainer.find('.description').height() >= 250)
        videoContainer.find('.video-info').addClass('long')

    refreshTimer = null
    refreshScreen = () ->
      updateScreen = () ->
        watchedVideos.save()
        unwatchedVideos.save()

        $('title').text((if unwatchedVideos.length() > 0 then "(#{unwatchedVideos.length()}) " else '') + title)

        $('#unwatched').find('.text').text("Unwatched (#{unwatchedVideos.length()})")
        $('#watched').find('.text').text("Watched (#{watchedVideos.length()})")

        onUnwatchedTab = $('#tab-unwatched').prop('checked')
        videoList = (if onUnwatchedTab then unwatchedVideos else watchedVideos)
        $videoList = (if onUnwatchedTab then $('.unwatched-videos') else $('.watched-videos'))
        for i in [0...$videoList.children().length]
          if ($("#" + videoList.get(i).link).length == 0)
            addVideoToDom($videoList, videoList.get(i), i)

        addOneVideo = () ->
          if ($(this).scrollTop() + $(this).innerHeight() * 2 >= $(document).height())
            for i in [0...videoList.length()]
              if ($("#" + videoList.get(i).link).length == 0)
                addVideoToDom($videoList, videoList.get(i), i)
                addOneVideo()
                break

        addOneVideo()

        refreshTimer = null;

      if refreshTimer?
        clearTimeout(refreshTimer)
      else
        updateScreen()

      refreshTimer = setTimeout(updateScreen, 100)

    $videos = $('.videos')
    $videos.on('click', '.mark', () ->
      id = $(this).parent().parent().attr('id')
      if unwatchedVideos.find(id)?
        watchedVideos.add(unwatchedVideos.find(id))
        unwatchedVideos.remove(id)
      else
        unwatchedVideos.add(watchedVideos.find(id))
        watchedVideos.remove(id)
      $("#" + id).remove()
      refreshScreen()
    )
    $('#all-done').click(() ->
      watchedVideos.add(video) for video in unwatchedVideos.videos
      unwatchedVideos.videos = []
      $('.unwatched-videos').children('.video-container').remove()
      refreshScreen();
    )
    $('#all-undone').click(() ->
      unwatchedVideos.add(video) for video in watchedVideos.videos
      watchedVideos.videos = []
      $('.watched-videos').children('.video-container').remove()
      refreshScreen();
    )
    $('input[name="tab"]').change(() ->
      if $('#tab-unwatched').prop('checked')
        $('.unwatched-videos').show()
        $('.watched-videos').hide()
      else
        $('.unwatched-videos').hide()
        $('.watched-videos').show()
      window.scrollTo(0, 0);
      refreshScreen();
    )

    $(window).bind('scroll', refreshScreen)

    readDataInterval = null
    updateInput = new SavedInput('#update-interval', 'update-interval', 5, () ->
      window.clearInterval(readDataInterval)
      readDataInterval = window.setInterval(readData, 1000 * 60 * updateInput.value())
    )
    #noinspection CoffeeScriptUnusedLocalSymbols
    readDataInterval = window.setInterval(readData, 1000 * 60 * updateInput.value())

    $('#refresh').click(readData)

    $videos.on('click', '.video', () ->
      new YT.Player(this, {
        height: $(this).width * 9 / 16,
        width: $(this).width,
        videoId: $(this).parent().attr('id'),
        events: {
          'onReady': onPlayerReady,
          'onStateChange': onPlayerStateChange,
        },
      })
    )

    onPlayerReady = (event) ->
      event.target.playVideo()

    $autoplay = $('#autoplay')
    $expand = $('#expand')

    onPlayerStateChange = (event) ->
      $video = $(event.target.f).parent()
      if event.data == YT.PlayerState.ENDED and $autoplay.is(':checked')
        $video.next().find('.video').click()
        $video.find('.done').click()

      $expanded = $video.find('.expanded')
      if event.data == YT.PlayerState.PLAYING and $expand.is(':checked')
        $expanded.prop('checked', true)
        $expanded.change()

      if event.data == YT.PlayerState.ENDED
        $expanded.prop('checked', false)
        $expanded.change()

    $autoplay.prop('checked', localStorage.getItem('autoplay') == 'true')
    $autoplay.change(() ->
      localStorage.setItem('autoplay', (if $autoplay.is(':checked') then 'true' else 'false'))
    )
    $expand.prop('checked', localStorage.getItem('expand') == 'true')
    $expand.change(() ->
      localStorage.setItem('expand', (if $expand.is(':checked') then 'true' else 'false'))
    )
  )