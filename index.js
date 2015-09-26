var unwatchedVideos = [];
var watchedVideos = [];
var daysIntoHistory = 28;
var title = "";

function readData() {
    $('#refresh').children('i').addClass('fa-spin');
    watchedVideos = JSON.parse(localStorage.getItem("watched-videos"));
    if (watchedVideos === null) {
        watchedVideos = [];
    }
    unwatchedVideos = JSON.parse(localStorage.getItem("unwatched-videos"));
    if (unwatchedVideos === null) {
        unwatchedVideos = [];
    }

    removeOldVideos(watchedVideos, new Date() - 1000 * 60 * 60 * 24 * daysIntoHistory);
    saveWatched();

    if (API_LOADED) {
        var getSubs = function (pageToken) {
            gapi.client.youtube.subscriptions.list({
                mine: true,
                part: 'snippet, contentDetails',
                maxResults: 50,
                pageToken: pageToken
            }).execute(function (response) {
                loadVideosFromChannel($.map(response.items, function (val) {
                    return val.snippet.resourceId.channelId;
                }));
                if (response.nextPageToken !== undefined) {
                    getSubs(response.nextPageToken);
                }
            });
        };
        getSubs(undefined);
    } else {
        addVideo();
    }

    function loadVideosFromChannel(channelIds) {
        gapi.client.youtube.channels.list({
            part: 'contentDetails',
            id: channelIds.join(',')
        }).execute(function (response) {
            response.items.forEach(function (val) {
                loadVideosFromPlaylist(val.contentDetails.relatedPlaylists.uploads);
            });
        });
    }

    function loadVideosFromPlaylist(playlistId) {
        gapi.client.youtube.playlistItems.list({
            part: 'snippet',
            playlistId: playlistId,
            maxResults: 10,
        }).execute(function (response) {
            response.items.forEach(function (item) {
                loadVideo(item.snippet);
            });
        });
    }

    function loadVideo(videoSnippet) {
        var thumbnail = null;
        $.each(videoSnippet.thumbnails, function (key, value) {
            if ((thumbnail === null || thumbnail.width < value.width) && value.url !== null) {
                thumbnail = value;
            }
        });
        var video = {
            title: videoSnippet.title,
            link: videoSnippet.resourceId.videoId,
            author: videoSnippet.channelTitle,
            authorId: videoSnippet.channelId,
            publishedDate: videoSnippet.publishedAt,
            description: videoSnippet.description,
            thumbnail: thumbnail.url,
        };
        if (Date.parse(video.publishedDate) > (new Date() - 1000 * 60 * 60 * 24 * daysIntoHistory)) {
            if (listContainsVideo(watchedVideos, video.link) === -1) {
                addToList(unwatchedVideos, video);
            }
        }
        checkCount = 10;
    }

    var checkCount = 10;
    var updateInterval = window.setInterval(function () {
        saveWatched();
        addVideo();
        checkCount--;
        if (checkCount < 0) {
            $('#refresh').children('i').removeClass('fa-spin');
            window.clearInterval(updateInterval);
        }
    }, 100);
}

function listContainsVideo(videos, id) {
    for(var i = 0; i < videos.length; i++) {
        if (videos[i].link == id) {
            return i;
        }
    }
    return -1;
}

function addToList(videos, video) {
    for (var i = 0; i < videos.length; i++) {
        if (videos[i].link == video.link) {
            // Already added, replace in case it's been updated.
            videos[i] = video;
            return;
        } else if (videos[i].publishedDate > video.publishedDate) {
            // In the right position
            videos.splice(i, 0, video);
            return;
        }
    }
    // If we get this far, we haven't added it yet.
    videos.splice(videos.length, 0, video);
}

function removeOldVideos(videos, date) {
    while (videos.length > 0 && Date.parse(videos[0].publishedDate) < date) {
        videos.splice(0, 1);
    }
}

function addVideoToDom(element, video) {
    var unwatchedVideo = listContainsVideo(unwatchedVideos, video.link) !== -1;

    var description = $('<div/>', {class: "description"});
    video.description.split(/\n(?:\n)+/).forEach(function (paragraph) {
        description.append($('<p>'+paragraph.replace(/\n/g, '<br>')+'</p>'));
    });
    description.find('p').linkify({ target: "_blank" });

    var videoContainer = $('<div/>', {class: 'video-container', id: video.link})
        .append($('<input/>', {type: 'checkbox', class: 'expanded', id: 'expand'+video.link}))
        .append($('<div/>', {class: "video"})
            .append($('<div/>', {class: "thumbnail"})
                .append($('<p/>', {text: video.title}))
                .append($('<img/>', {src: video.thumbnail}))
                .append($('<i/>', {class: 'fa fa-play fa-3x'}))))
        .append($('<div/>', {class: 'video-info'})
            .append($('<div/>', {class: 'author'})
                .append($('<a/>', {href: 'http://www.youtube.com/channel/'+video.authorId, target: "_blank", text: 'by '+video.author})))
            .append($('<div/>', {class: 'upload-date', text: 'uploaded '+(new Date(video.publishedDate)).toLocaleString()}))
            .append($('<input/>', {type: 'checkbox', class: 'truncated', id: 'trunc'+video.link, 'checked': true}))
            .append(description)
            .append($('<label/>', {for: 'trunc'+video.link})
                .append($('<span/>', {class: 'read-more', text: 'Read more'}))
                .append($('<span/>', {class: 'read-less', text: 'Read less'}))))
        .append($('<div/>', {class: 'side-buttons'})
            .append($('<button/>', {class: (unwatchedVideo ? 'done' : 'undone')+' btn btn-default', title: "Mark as "+(unwatchedVideo ? 'watched' : 'unwatched'), })
                .append($('<i/>', {class: 'fa fa-'+(unwatchedVideo ? "check" : "remove")+' fa-3x'})))
            .append($('<a/>', {class: 'youtube-watch btn btn-default', title: "Watch on YouTube", href: "https://www.youtube.com/watch?v="+video.link, target: "_blank"})
                .append($('<i/>', {class: 'fa fa-youtube fa-3x'})))
            .append($('<label/>', {for: 'expand'+video.link})
                .append($('<div/>', {class: 'expand-player btn btn-default', title: "Expand Video"})
                    .append($('<i/>', {class: 'fa fa-expand fa-3x'})))
                .append($('<div/>', {class: 'compress-player btn btn-default', title: "Compress Video"})
                    .append($('<i/>', {class: 'fa fa-compress fa-3x'})))));
    $('.expanded').change(function () {
        var video = $(this).next();
        video.height(video.width() * 9 / 16)
    });

    element.append(videoContainer);

    if (videoContainer.find('.description').height() >= 250) {
        videoContainer.find('.video-info').addClass('long');
    }
}

function saveWatched() {
    localStorage.setItem("watched-videos", JSON.stringify(watchedVideos));
    localStorage.setItem("unwatched-videos", JSON.stringify(unwatchedVideos));
}

function updateCounts() {
    $("#unwatched").find(".text").text(`Unwatched (${unwatchedVideos.length})`);
    $('title').text((unwatchedVideos.length > 0 ? `(${unwatchedVideos.length}) ` : "") + title);
    $("#watched").find(".text").text(`Watched (${watchedVideos.length})`);
}

function addVideo() {
    updateCounts();
    if($(this).scrollTop() + $(this).innerHeight() * 2 >= $(document).height()) {
        // If we're at the bottom of the page

        var i;
        if ($('#tab-unwatched').prop('checked')) {
            for (i = 0; i < unwatchedVideos.length; i++) {
                if ($("#"+unwatchedVideos[i].link).length === 0) {
                    // Isn't already on screen
                    addVideoToDom($('.unwatched-videos'), unwatchedVideos[i]);
                    addVideo();
                    return;
                }
            }
        } else {
            for (i = watchedVideos.length-1; i >= 0; i--) {
                if ($("#"+watchedVideos[i].link).length === 0) {
                    // Isn't already on screen
                    addVideoToDom($('.watched-videos'), watchedVideos[i]);
                    addVideo();
                    return;
                }
            }
        }
    }
}

$(document).ready(function () {
    title = $('title').text();
    var videos = $(".videos");
    videos.on("click", ".done", function () {
        var id = $(this).parent().parent().attr('id');
        addToList(watchedVideos, unwatchedVideos[listContainsVideo(unwatchedVideos, id)]);
        unwatchedVideos.splice(listContainsVideo(unwatchedVideos, id), 1);
        $("#"+id).remove();
        saveWatched();
        addVideo();
    });
    videos.on("click", ".undone", function () {
        var id = $(this).parent().parent().attr('id');
        addToList(unwatchedVideos, watchedVideos[listContainsVideo(watchedVideos, id)]);
        watchedVideos.splice(listContainsVideo(watchedVideos, id), 1);
        $("#"+id).remove();
        saveWatched();
        addVideo();
    });
    $("#all-done").click(function () {
        unwatchedVideos.forEach(function (video) {
            addToList(watchedVideos, video);
        });
        unwatchedVideos = [];
        $(".video-container").remove();
        saveWatched();
        addVideo();
    });
    $("#all-undone").click( function () {
        watchedVideos.forEach(function (video) {
            addToList(unwatchedVideos, video);
        });
        watchedVideos = [];
        $(".video-container").remove();
        saveWatched();
        addVideo();
    });
    $('input[name="tab"]').change(function () {
        if ($('#tab-unwatched').prop('checked')) {
            $('.unwatched-videos').show();
            $('.watched-videos').hide();
        } else {
            $('.unwatched-videos').hide();
            $('.watched-videos').show();
        }
        window.scrollTo(0,0);
        addVideo();
    });

    $(window).bind('scroll', addVideo);

    var updateInput = $('#update-interval');
    var interval = localStorage.getItem("update-interval");
    interval = interval !== null ? interval : 5;
    updateInput.val(interval);
    var readDataInterval = window.setInterval(readData, 1000 * 60 * updateInput.val());
    updateInput.change(function () {
        window.clearInterval(readDataInterval);
        if (updateInput.val() > 0) {
            readDataInterval = window.setInterval(readData, 1000 * 60 * updateInput.val());
        }
        localStorage.setItem("update-interval", updateInput.val());
    });
    daysIntoHistory = localStorage.getItem("days-into-history");
    daysIntoHistory = daysIntoHistory !== null ? daysIntoHistory : 28;
    var historyInput = $('#history-length');
    historyInput.val(daysIntoHistory);
    historyInput.change(function () {
        daysIntoHistory = Math.max(0, historyInput.val());
        localStorage.setItem("days-into-history", daysIntoHistory);
    });
    $('#refresh').click(readData);

    videos.on('click', '.video', function () {
        new YT.Player(this, {
            height: $(this).width * 9 / 16,
            width: $(this).width,
            videoId: $(this).parent().attr('id'),
            events: {
                'onReady': onPlayerReady,
                'onStateChange': onPlayerStateChange,
            },
        });
    });
    function onPlayerReady(event) {
        event.target.playVideo();
    }
    var autoplay =  $('#autoplay');
    var expand = $('#expand');

    function onPlayerStateChange(event) {
        var video = $(event.target.f).parent();
        if (event.data == YT.PlayerState.ENDED && autoplay.is(':checked')) {
            video.next().find('.video').click();
            video.find('.done').click();
        }

        if (event.data == YT.PlayerState.PLAYING && expand.is(':checked')) {
            video.find('.expanded').prop('checked', true);
            video.find('.expanded').change();
        }

        if (event.data == YT.PlayerState.ENDED) {
            video.find('.expanded').prop('checked', false);
            video.find('.expanded').change();
        }
    }

    autoplay.prop('checked', localStorage.getItem('autoplay') == 'true');
    autoplay.change(function () {
        localStorage.setItem('autoplay', autoplay.is(':checked') ? 'true' : 'false');
    });

    expand.prop('checked', localStorage.getItem('expand') == 'true');
    expand.change(function () {
        localStorage.setItem('expand', autoplay.is(':checked') ? 'true' : 'false');
    });
});