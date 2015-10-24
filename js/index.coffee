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

      videoContainer = $('<div/>', {class: 'video-container', id: 'video-' + @id})
      .append($('<input/>', {type: 'checkbox', class: 'expanded', id: 'expand-' + @id}))
      .append($('<div/>', class: 'video')
      .append($('<div/>', class: 'thumbnail')
      .append($('<p/>', text: @title))
      .append($('<img/>', src: @thumbnail))
      .append($('<i/>', class: 'fa fa-play fa-3x'))))
      .append($('<div/>', class: 'video-info')
      .append($('<div/>', class: 'author')
      .append($('<a/>', {
        href: 'http://www.youtube.com/channel/' + @authorId,
        target: '_blank',
        text: 'by ' + @author
      })))
      .append($('<div/>', {class: 'upload-date', text: 'uploaded ' + new Date(@publishedDate).toLocaleString()}))
      .append($('<input/>', {type: 'checkbox', class: 'truncated', id: 'trunc-' + @id, 'checked': true}))
      .append(description)
      .append($('<label/>', for: 'trunc-' + @id)
      .append($('<span/>', {class: 'read-more', text: 'Read more'}))
      .append($('<span/>', {class: 'read-less', text: 'Read less'}))))
      .append($('<div/>', class: 'side-buttons')
      .append($('<button/>', {
        class: 'mark btn btn-default',
        title: 'Mark as ' + (if isUnwatchedVideo then 'watched' else 'unwatched')
      })
      .append($('<i/>', class: 'fa fa-' + (if isUnwatchedVideo then 'check' else 'remove') + ' fa-3x')))
      .append($('<a/>', {
        class: 'youtube-watch btn btn-default',
        title: 'Watch on YouTube',
        href: 'https://www.youtube.com/watch?v=' + @id,
        target: '_blank'
      })
      .append($('<i/>', class: 'fa fa-youtube fa-3x')))
      .append($('<label/>', for: 'expand-' + @id)
      .append($('<div/>', {class: 'expand-player btn btn-default', title: 'Expand Video'})
      .append($('<i/>', class: 'fa fa-expand fa-3x')))
      .append($('<div/>', {class: 'compress-player btn btn-default', title: 'Compress Video'})
      .append($('<i/>', class: 'fa fa-compress fa-3x')))))

      # Place the video into the dom.
      if (index == 0)
        parent.prepend(videoContainer)
      else if (index > $(parent).children().length)
        parent.append(videoContainer);
      else
        # The :nth-child selector is 1-indexed.
        parent.children(":nth-child(#{index})").after(videoContainer)

      $('.expanded').change(() ->
        videoElement = $(this).next()
        videoElement.height(videoElement.width() * 9 / 16)
      )

      if (videoContainer.find('.description').height() >= 250)
        videoContainer.find('.video-info').addClass('long')

      id = @id # Annoying thing to deal with closures.
      videoContainer.on('click', '.mark', () ->
        if isUnwatchedVideo
          watchedVideos.add(unwatchedVideos.remove(id))
        else
          unwatchedVideos.add(watchedVideos.remove(id))
      )

      videoContainer.on('click', '.video', () ->
        new YT.Player(this, {
          height: $(this).width * 9 / 16,
          width: $(this).width,
          videoId: id,
          events: {
            'onReady': onPlayerReady,
            'onStateChange': onPlayerStateChange,
          },
        })
      )


  class VideoList
    constructor: (@storageString, selector, reversed = false) ->
      @htmlElement = $(selector)
      videoList = JSON.parse(localStorage.getItem(@storageString)) or []
      @videos = (Video.fromJson(video) for video in videoList)
      @order = (if reversed then 1 else -1)
      @sort()
      @deduplicate()
      @save()

    add: (newVideo) ->
      index = @indexOf(newVideo.id)
      if index == -1
        # New video
        @videos.push(newVideo)
        @sort()
        @deduplicate()
        @save()
        # Update visuals
        if @htmlElement.children().length > @indexOf(newVideo.id)
          newVideo.addToDom(@htmlElement, @indexOf(newVideo.id))
          lastChild = @htmlElement.children().last()
          if lastChild.find('.thumbnail').length > 0
            lastChild.remove()
        window.refresh()
      else
        # Video already in list.
        @videos[index] = newVideo
      return @

    remove: (id) ->
      index = @indexOf(id)
      if index != -1
        video = @videos[index]
        @videos.splice(index, 1)
        @sort()
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
        if video.publishedDate < date
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
      @sort()
      @deduplicate()
      @save()
      sourceList.videos = []
      sourceList.save()
      # Unrender all non playing videos. When they're re-rendered they'll be in the right order.
      for child in @htmlElement.children('.video-container')
        element = $(child)
        if element.find('.thumbnail').length > 0
          element.remove()
      sourceList.htmlElement.children('.video-container').remove()
      window.refresh()

  class SavedInput
    constructor: (@selector, @storageString, defaultValue, listener) ->
      @property = (if $(@selector).prop('type') == 'checkbox' then 'checked' else 'value')
      value = JSON.parse(localStorage.getItem(@storageString)) or defaultValue
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
      JSON.parse(localStorage.getItem(@storageString))

  title = $('title').text()

  # Saved input boxes.
  historyInput = new SavedInput('#history-length', 'days-into-history', 28)
  autoplayInput = new SavedInput('#autoplay', 'autoplay', false)
  expandInput = new SavedInput('#expand', 'expand', false)

  watchedVideos = new VideoList("watched-videos", '.watched-videos')
  unwatchedVideos = new VideoList("unwatched-videos", '.unwatched-videos', true)

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
      if video.publishedDate > (new Date() - 1000 * 60 * 60 * 24 * historyInput.value())
        if watchedVideos.find(video.id)?
          watchedVideos.add(video)
        else
          unwatchedVideos.add(video)

    getSubs() if window.API_LOADED

  $('#refresh').click(window.readData)

  # Update interval
  readDataInterval = null
  updateInput = new SavedInput('#update-interval', 'update-interval', 5, () ->
    window.clearInterval(readDataInterval)
    if updateInput.value() > 0
      readDataInterval = window.setInterval(readData, 1000 * 60 * updateInput.value())
  )
  #noinspection CoffeeScriptUnusedLocalSymbols
  readDataInterval = window.setInterval(readData, 1000 * 60 * updateInput.value())

  window.refresh = () ->
    $('title').text((if unwatchedVideos.length() > 0 then "(#{unwatchedVideos.length()}) " else '') + title)

    $('#unwatched').find('.text').text("Unwatched (#{unwatchedVideos.length()})")
    $('#watched').find('.text').text("Watched (#{watchedVideos.length()})")

    if $('#tab-unwatched').prop('checked')
      unwatchedVideos.addVideoToDom()
    else
      watchedVideos.addVideoToDom()
  window.refresh()
  $(window).bind('scroll', window.refresh)

  # Click binds
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

  # YouTube player functions
  onPlayerReady = (event) ->
    event.target.playVideo()

  onPlayerStateChange = (event) ->
    $video = $(event.target.f).parent()
    if event.data == YT.PlayerState.ENDED and autoplayInput.value() and $('#tab-unwatched').prop('checked')
      $video.next().find('.video').click()
      $video.find('.mark').click()

    $expanded = $video.find('.expanded')
    if event.data == YT.PlayerState.PLAYING and expandInput.value()
      $expanded.prop('checked', true)
      $expanded.change()

    if event.data == YT.PlayerState.ENDED
      $expanded.prop('checked', false)
      $expanded.change()
)