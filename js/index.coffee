$(document).ready(() ->
  class Video
    constructor: (@title, @id, @author, @authorId, publishedDate, @description, @thumbnail) ->
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
      )

    addToDom: (parent, index) ->
      isUnwatchedVideo = unwatchedVideos.find(@id)?

      description = $('<div/>', {class: "description"})
      @description.split(/\n(?:\n)+/).forEach((paragraph) ->
        description.append($('<p>' + paragraph.replace(/\n/g, '<br>') + '</p>'))
      )
      description.find('p').linkify({target: "_blank"})

      videoContainer = $('<div/>',
        class: 'video-container'
        id: 'video-' + @id).append($('<input/>',
        type: 'checkbox'
        class: 'expanded'
        id: 'expand' + @id)).append($('<div/>', class: 'video').append($('<div/>',
        class: 'thumbnail').append($('<p/>', text: @title)).append($('<img/>', src: @thumbnail)).append($('<i/>',
        class: 'fa fa-play fa-3x')))).append($('<div/>', class: 'video-info').append($('<div/>',
        class: 'author').append($('<a/>',
        href: 'http://www.youtube.com/channel/' + @authorId
        target: '_blank'
        text: 'by ' + @author))).append($('<div/>',
        class: 'upload-date'
        text: 'uploaded ' + new Date(@publishedDate).toLocaleString())).append($('<input/>',
        type: 'checkbox'
        class: 'truncated'
        id: 'trunc' + @id
        'checked': true)).append(description).append($('<label/>', for: 'trunc' + @id).append($('<span/>',
        class: 'read-more'
        text: 'Read more')).append($('<span/>',
        class: 'read-less'
        text: 'Read less')))).append($('<div/>', class: 'side-buttons').append($('<button/>',
        class: 'mark btn btn-default'
        title: 'Mark as ' + (if isUnwatchedVideo then 'watched' else 'unwatched')).append($('<i/>',
        class: 'fa fa-' + (if isUnwatchedVideo then 'check' else 'remove') + ' fa-3x'))).append($('<a/>',
        class: 'youtube-watch btn btn-default'
        title: 'Watch on YouTube'
        href: 'https://www.youtube.com/watch?v=' + @id
        target: '_blank').append($('<i/>', class: 'fa fa-youtube fa-3x'))).append($('<label/>',
        for: 'expand' + @id).append($('<div/>',
        class: 'expand-player btn btn-default'
        title: 'Expand Video').append($('<i/>', class: 'fa fa-expand fa-3x'))).append($('<div/>',
        class: 'compress-player btn btn-default'
        title: 'Compress Video').append($('<i/>', class: 'fa fa-compress fa-3x')))))

      $('.expanded').change(() ->
        videoElement = $(this).next()
        videoElement.height(videoElement.width() * 9 / 16)
      )

      if (index == 0)
        parent.prepend(videoContainer)
      else if (index > $(parent).children().length)
        parent.append(videoContainer);
      else
        parent.children(":nth-child(#{index})").after(videoContainer)

      if (videoContainer.find('.description').height() >= 250)
        videoContainer.find('.video-info').addClass('long')

  class VideoList
    constructor: (@storageString, selector, reversed = false) ->
      @htmlElement = $(selector)
      videoList = JSON.parse(localStorage.getItem(@storageString)) or []
      @videos = (Video.fromJson(video) for video in videoList)
      @order = (if reversed then 1 else -1)
      @clean()

    add: (newVideo) ->
      index = @indexOf(newVideo.id)
      if index == -1
        @videos.push(newVideo)
        @clean()
        # Update visuals
        if @htmlElement.children().length > @indexOf(newVideo.id)
          newVideo.addToDom(@htmlElement, @indexOf(newVideo.id))
        window.refresh()
      else
        @videos[index] = newVideo
      return @

    remove: (id) ->
      index = @indexOf(id)
      if index != -1
        video = @videos[index]
        @videos.splice(index, 1)
        @save()
        # Update visuals
        $('#video-' + video.id).remove()
        window.refresh()
        video

    indexOf: (id) ->
      for i in [0...@videos.length]
        if @videos[i].id == id
          return i
      -1

    get: (index) ->
      @videos[index]

    find: (id) ->
      for video in @videos
        if video.id == id
          return video

    length: () ->
      @videos.length

    clearOlderThan: (date) ->
      for video in @videos
        if new Date(video.publishedDate) < date
          @remove(video.id)

    sort: () ->
      order = @order
      @videos = @videos.sort((a, b) -> (if a.publishedDate > b.publishedDate then 1 else -1) * order)
      return @

    deduplicate: () ->
      temp = @videos
      @videos = []
      for video in temp
        if !@find(video.id)?
          @videos.push(video)

    save: () ->
      localStorage.setItem(@storageString, JSON.stringify(@videos))

    clean: () ->
      @clearOlderThan()
      @sort()
      @deduplicate()
      @save()

    addVideoToDom: () ->
      if ($(window).scrollTop() + $(window).innerHeight() * 2 >= $(document).height())
        for i in [0...@length()]
          video = @get(i)
          if ($("#video-" + video.id).length == 0)
            video.addToDom(@htmlElement, i)
            @addVideoToDom()
            break

    addAllFrom: (sourceList) ->
      @videos = @videos.concat(sourceList.videos)
      @clean()
      sourceList.videos = []
      sourceList.clean()
      for i in [0...@htmlElement.children().length]
        video = @get(i)
        if @htmlElement.children('#video-'+video.id).length == 0
          video.addToDom(@htmlElement, i)
      sourceList.htmlElement.children('.video-container').remove()
      window.refresh()

  class SavedInput
    constructor: (@selector, @storageString, defaultValue, listener) ->
      @property = (if $(@selector).prop('type') == 'checkbox' then 'checked' else 'value')
      value = localStorage.getItem(@storageString) or defaultValue
      localStorage.setItem(@storageString, value)
      $(@selector).prop(@property, value)
      self = @
      $(@selector).change((e) ->
        localStorage.setItem(self.storageString, $(self.selector).prop(self.property))
        listener(e) if listener?
      )
    value: (value) ->
      if value?
        localStorage.setItem(@storageString, value)
        $(@selector).prop(@property, value)
      localStorage.getItem(@storageString)

  title = $('title').text()
  historyInput = new SavedInput('#history-length', 'days-into-history', 28)
  watchedVideos = new VideoList("watched-videos", '.watched-videos')
  unwatchedVideos = new VideoList("unwatched-videos", '.unwatched-videos', true)

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
      if video.publishedDate > (new Date() - 1000 * 60 * 60 * 24 * historyInput.value())
        if watchedVideos.find(video.id)?
          watchedVideos.add(video)
        else
          unwatchedVideos.add(video)

    getSubs() if window.API_LOADED

  window.refresh = () ->
    $('title').text((if unwatchedVideos.length() > 0 then "(#{unwatchedVideos.length()}) " else '') + title)

    $('#unwatched').find('.text').text("Unwatched (#{unwatchedVideos.length()})")
    $('#watched').find('.text').text("Watched (#{watchedVideos.length()})")

    if $('#tab-unwatched').prop('checked')
      unwatchedVideos.addVideoToDom()
    else
      watchedVideos.addVideoToDom()
  window.refresh()

  $videos = $('.videos')
  $videos.on('click', '.mark', () ->
    id = $(this).parent().parent().attr('id')[6..]
    if unwatchedVideos.find(id)?
      watchedVideos.add(unwatchedVideos.remove(id))
    else
      unwatchedVideos.add(watchedVideos.remove(id))
  )
  $('#all-done').click(() ->
    watchedVideos.addAllFrom(unwatchedVideos)
  )
  $('#all-undone').click(() ->
    unwatchedVideos.addAllFrom(watchedVideos)
  )
  $('input[name="tab"]').change(() ->
    if $('#tab-unwatched').prop('checked')
      $('.unwatched-videos').show()
      $('.watched-videos').hide()
    else
      $('.unwatched-videos').hide()
      $('.watched-videos').show()
    window.scrollTo(0, 0);
    window.refresh()
  )

  $(window).bind('scroll', window.refresh)

  readDataInterval = null
  updateInput = new SavedInput('#update-interval', 'update-interval', 5, () ->
    window.clearInterval(readDataInterval)
    if updateInput.value() > 0
      readDataInterval = window.setInterval(readData, 1000 * 60 * updateInput.value())
  )
  #noinspection CoffeeScriptUnusedLocalSymbols
  readDataInterval = window.setInterval(readData, 1000 * 60 * updateInput.value())

  $('#refresh').click(window.readData)

  $videos.on('click', '.video', () ->
    new YT.Player(this, {
      height: $(this).width * 9 / 16,
      width: $(this).width,
      videoId: $(this).parent().attr('id')[6..],
      events: {
        'onReady': onPlayerReady,
        'onStateChange': onPlayerStateChange,
      },
    })
  )

  onPlayerReady = (event) ->
    event.target.playVideo()

  # TODO: Work out why this doesn't work.
#  autoplayInput = new SavedInput('#autoplay', 'autoplay', false)
#  expandInput = new SavedInput('#expand', 'expand', false)
  $autoplay = $('#autoplay')
  $autoplay.prop('checked', localStorage.getItem('autoplay') == 'true')
  $autoplay.change(() ->
    localStorage.setItem('autoplay', (if $autoplay.is(':checked') then 'true' else 'false'))
  )
  $expand = $('#expand')
  $expand.prop('checked', localStorage.getItem('expand') == 'true')
  $expand.change(() ->
    localStorage.setItem('expand', (if $expand.is(':checked') then 'true' else 'false'))
  )

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
)