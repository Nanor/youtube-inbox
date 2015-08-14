/* global $, window, XMLHttpRequest, ActiveXObject, document, alert, localStorage */

var videos = [];
var watchedVideos = [];
var unwatched = true;

function readData() {
	var uncheckedWatched = localStorage.getItem("watched-list");
	if (uncheckedWatched === null) {
		uncheckedWatched = [];
	}
	videos = [];
	var needsUpdate = 10;
	var xhr;

	function loadVideosFromPlaylist(playlistId) {
		gapi.client.youtube.playlistItems.list({
			part: 'snippet',
			playlistId: playlistId,
			maxResults: 10
		}).execute(function (response) {
			response.items.forEach(function (item) {
				loadVideo(item.snippet);
			});
		});
	}
	
	function loadVideosFromChannel(channelId) {
		gapi.client.youtube.channels.list({
			part: 'contentDetails',
			id: channelId,
		}).execute(function (response) {
			loadVideosFromPlaylist(response.items[0].contentDetails.relatedPlaylists.uploads);
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
		if (uncheckedWatched.indexOf(video.link) !== -1) {
			watchedVideos.push(video.link);
		}
		videos.push(video);
		needsUpdate = 10;
	}
	
	if (API_LOADED) {
		var getSubs = function (pageToken) {
			gapi.client.youtube.subscriptions.list({
				mine: true,
				part: 'snippet',
				maxResults: 50,
				pageToken: pageToken								
			}).execute(function (response) {
				response.items.forEach(function (snippet) {
					loadVideosFromChannel(snippet.snippet.resourceId.channelId);
				});
				if (response.nextPageToken !== undefined) {
					getSubs(response.nextPageToken);
				}
			});
		}
		getSubs(undefined);
	}
	
	var updateInterval = window.setInterval(function () {
		if (needsUpdate > 0) {
			if (needsUpdate === 10) {
				addVideo();
			}
			needsUpdate--;
		} else {
			window.clearInterval(updateInterval);
		}
	}, 1000);
}

function getCode(video) {
	return ''+
	'<div class="video-container" id="'+video.link+'">'+
		'<iframe class="video" width="560" height="315" src="https://www.youtube.com/embed/'+video.link+'" frameborder="0" allowfullscreen></iframe>'+
		'<div class="video-info">'+
			'<div class="author">by '+video.author+'</div>'+
			'<div class="description">'+video.description+'</div>'+
		'</div>'+
		'<div class="buttons">'+
			'<button class="done"><i class="fa fa-'+ (unwatched ? 'check' : 'remove') +' fa-3x"></i></button>'+
			'<button class="youtube-watch"><i class="fa fa-youtube fa-3x"></i></button>'+
		'</div>'+
	'</div>';
}

function saveWatched() {
	localStorage.setItem("watched-list", watchedVideos);
}

function addVideo() {
	displayNoVideos();
	videos.sort(function (a, b) {
		if (unwatched) {
			return Date.parse(a.publishedDate) - Date.parse(b.publishedDate);
		} else {
			return Date.parse(b.publishedDate) - Date.parse(a.publishedDate);
		}
	});
	if($(this).scrollTop() + $(this).innerHeight() * 2 >= $(document).height()) {
		for (var i = 0; i < videos.length; i++) {
			var video = videos[i];
			if (((watchedVideos.indexOf(video.link) === -1) == unwatched) && ($("#"+video.link).length === 0)) {
				$(".videos").append(getCode(video));
				addVideo();
				break;
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

$(window).bind('scroll', addVideo);
window.setInterval(readData, 1000 * 60 * 5);

$(document).ready(function () {	
	$(".videos").on("click", ".done", function () {
		var id = $(this).parent().parent().attr('id');
		if(unwatched) {
			watchedVideos.push(id);
		} else {
			watchedVideos.splice(watchedVideos.indexOf(id), 1);
		}
		$("#"+id).remove();
		saveWatched();
		addVideo();
	});
	$("#all-done").click(function () {
		if (unwatched) {
			videos.forEach(function (video) {
				watchedVideos.push(video.link);
			});
		} else {
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
	$("#unwatched").addClass("selected");
	unwatched = ($(".selected").attr("id") === "unwatched");
	$(".videos").height = $(document).height;
	$("#all-undone").hide();
	
	displayNoVideos();
});