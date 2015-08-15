/* global $, window, XMLHttpRequest, ActiveXObject, document, alert, localStorage, gapi, API_LOADED, console, separator */

var unwatchedVideos = [];
var watchedVideos = [];
var unwatched = true;

function readData() {
	var watchedVideosTemp = JSON.parse(localStorage.getItem("watched-videos"));
	if (watchedVideosTemp === null) {
		watchedVideosTemp = [];
	}
	watchedVideos = [];
  unwatchedVideos = JSON.parse(localStorage.getItem("unwatched-videos"));
	if (unwatchedVideos === null) {
		unwatchedVideos = [];
	}

	if (API_LOADED) {
		var getSubs = function (pageToken) {
			gapi.client.youtube.subscriptions.list({
				mine: true,
				part: 'snippet, contentDetails',
				maxResults: 50,
				pageToken: pageToken								
			}).execute(function (response) {
				loadVideosFromChannel($.map(response.items, function (val) {
					if (val.contentDetails.newItemCount > 0) {
						return val.snippet.resourceId.channelId;
					} else {
						return "";
					}
				}));
				if (response.nextPageToken !== undefined) {
					getSubs(response.nextPageToken);
				}
			});
		};
		getSubs(undefined);
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
		var video = {
			title: videoSnippet.title,
			link: videoSnippet.resourceId.videoId,	
			author: videoSnippet.channelTitle,
			publishedDate: videoSnippet.publishedAt,
			description: videoSnippet.description,
		};
		
		if (listContainsVideo(watchedVideosTemp, video.link) !== -1) {
			addToList(watchedVideos, video);
		} else {
			addToList(unwatchedVideos, video);
		}
	}
	
	var checkCount = 10;
	var updateInterval = window.setInterval(function () {
		addVideo();
		checkCount--;
		if (checkCount < 0) {
			window.clearInterval(updateInterval);
		}
	}, 1000);
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
			// Already added
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

function getCode(video) {
	return ''+
	'<div class="video-container" id="'+video.link+'">'+
		'<iframe class="video" width="560" height="315" src="https://www.youtube.com/embed/'+video.link+'" frameborder="0" allowfullscreen></iframe>'+
		'<div class="video-info">'+
			'<div class="author">by '+video.author+'</div>'+
			'<div class="upload-date">uploaded '+video.publishedDate+'</div>'+
			'<div class="description">'+video.description+'</div>'+
		'</div>'+
		'<div class="buttons">'+
			'<button class="done"><i class="fa fa-'+ (unwatched ? 'check' : 'remove') +' fa-3x"></i></button>'+
			'<button class="youtube-watch"><i class="fa fa-youtube fa-3x"></i></button>'+
		'</div>'+
	'</div>';
}

function saveWatched() {
	localStorage.setItem("watched-videos", JSON.stringify(watchedVideos));
	localStorage.setItem("unwatched-videos", JSON.stringify(unwatchedVideos));
}

function addVideo() {
	displayNoVideos();
	if($(this).scrollTop() + $(this).innerHeight() * 2 >= $(document).height()) {
		// If we're at the bottom of the page
		
		var i;
		if (unwatched) {
			for (i = 0; i < unwatchedVideos.length; i++) {
				if ($("#"+unwatchedVideos[i].link).length === 0) {
					// Isn't already on screen
					$(".videos").append(getCode(unwatchedVideos[i]));
					addVideo();
					return;
				}
			}
		} else {
			for (i = watchedVideos.length-1; i >= 0; i--) {
				if ($("#"+watchedVideos[i].link).length === 0) {
					// Isn't already on screen
					$(".videos").append(getCode(watchedVideos[i]));
					addVideo();
					return;
				}
			}
		}
	}
}

function displayNoVideos() {
	if ($(".video").length === 0) {
		$(".no-videos").show();
	} else {
		$(".no-videos").hide();
	}
}

$(document).ready(function () {	
	$(".videos").on("click", ".done", function () {
		var id = $(this).parent().parent().attr('id');
		if(unwatched) {
			addToList(watchedVideos, unwatchedVideos[listContainsVideo(unwatchedVideos, id)]);
			unwatchedVideos.splice(listContainsVideo(unwatchedVideos, id), 1);
		} else {
			addToList(unwatchedVideos, watchedVideos[listContainsVideo(watchedVideos, id)]);
			watchedVideos.splice(listContainsVideo(watchedVideos, id), 1);
		}
		$("#"+id).remove();
		saveWatched();
		addVideo();
	});
	$("#all-done").click(function () {
		if (unwatched) {
			unwatchedVideos.forEach(function (video) {
				addToList(watchedVideos, video);
			});
			unwatchedVideos = [];
		} else {
			watchedVideos.forEach(function (video) {
				addToList(unwatchedVideos, video);
			});
			watchedVideos = [];
		}
		$(".video-container").remove();
		saveWatched();
		addVideo();
	});
	$(".videos").on("click", ".youtube-watch", function () {
		var id = $(this).parent().parent().attr('id');
		window.open("https://www.youtube.com/watch?v="+id);
	});
	$(".tab-bar").on("click", ".tab", function () {
		$(".tab").removeClass("selected");
		$(this).addClass("selected");
		unwatched = ($(".selected").attr("id") === "unwatched");
		if (unwatched) {
			$("#all-done").show();
			$("#all-undone").hide();
		} else {
			$("#all-undone").show();
			$("#all-done").hide();
		}
		$(".video-container").remove();
		addVideo();
	});
	
	$(window).bind('scroll', addVideo);
	window.setInterval(readData, 1000 * 60 * 5);
	
	$("#unwatched").addClass("selected");
	unwatched = ($(".selected").attr("id") === "unwatched");
	$(".videos").height = $(document).height;
	$("#all-undone").hide();
	
	displayNoVideos();
});