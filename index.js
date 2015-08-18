var unwatchedVideos = [];
var watchedVideos = [];
var unwatched = true;

var daysIntoHistory = 28;

function readData() {
	watchedVideos = JSON.parse(localStorage.getItem("watched-videos"));
	if (watchedVideos === null) {
		watchedVideos = [];
	}
	unwatchedVideos = JSON.parse(localStorage.getItem("unwatched-videos"));
	if (unwatchedVideos === null) {
		unwatchedVideos = [];
	}

	removeOldVideos(watchedVideos, new Date() - 1000 * 60 * 60 * 24 * daysIntoHistory);

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
		if (Date.parse(video.publishedDate) > (new Date() - 1000 * 60 * 60 * 24 * daysIntoHistory)) {
			if (listContainsVideo(watchedVideos, video.link) === -1) {
				addToList(unwatchedVideos, video);
			}
		}
		updateCounts();
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

function removeOldVideos(videos, date) {
	while (videos.length > 0 && Date.parse(videos[0].publishedDate) < date) {
		videos.splice(0, 1);
	}
}

function addVideoToDom(element, video) {

	var description = $('<div/>', {class: "description"});
	video.description.split(/\n(?:\n)+/).forEach(function (paragraph) {
		description.append($('<p>'+paragraph.replace(/\n/g, '<br>')+'</div>'));
	});

	element.append(
			$('<div/>', {class: 'video-container row', id: video.link})
					.append($(`<iframe src="https://www.youtube.com/embed/${video.link}" frameborder="0" allowfullscreen></iframe>`).addClass("video col-md-6"))
					.append($('<div/>', {class: 'video-info col-md-5'})
							.append($('<div/>', {class: 'author', text: 'by '+video.author}))
							.append($('<div/>', {class: 'upload-date', text: 'uploaded '+(new Date(video.publishedDate)).toLocaleString()}))
							.append(description)
							.append($('<button/>', {class: 'read-more', text: 'Read more'}))
							.append($('<button/>', {class: 'read-less', text: 'Read less'})))
					.append($('<div/>', {class: 'buttons col-md-1'})
							.append($('<button/>', {class: (unwatched ? 'done' : 'undone')+' btn btn-default', title: "Mark as "+(unwatched ? 'watched' : 'unwatched'), })
									.append($('<i/>', {class: 'fa fa-'+(unwatched ? "check" : "remove")+' fa-3x'})))
							.append($('<button/>', {class: 'youtube-watch btn btn-default', title: "Watch on YouTube"})
									.append($('<i/>', {class: 'fa fa-youtube fa-3x'}))))
	);
}

function saveWatched() {
	localStorage.setItem("watched-videos", JSON.stringify(watchedVideos));
	localStorage.setItem("unwatched-videos", JSON.stringify(unwatchedVideos));
}

function updateCounts() {
	$("#unwatched").find(".text").text(`Unwatched (${unwatchedVideos.length})`);
	$("#watched").find(".text").text(`Watched (${watchedVideos.length})`);
}

function addVideo() {
	updateCounts();
	displayNoVideos();
	if($(this).scrollTop() + $(this).innerHeight() * 2 >= $(document).height()) {
		// If we're at the bottom of the page

		var i;
		if (unwatched) {
			for (i = 0; i < unwatchedVideos.length; i++) {
				if ($("#"+unwatchedVideos[i].link).length === 0) {
					// Isn't already on screen
					addVideoToDom($('.videos'), unwatchedVideos[i]);
					addVideo();
					return;
				}
			}
		} else {
			for (i = watchedVideos.length-1; i >= 0; i--) {
				if ($("#"+watchedVideos[i].link).length === 0) {
					// Isn't already on screen
					addVideoToDom($('.videos'), watchedVideos[i]);
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
	videos.on("click", ".youtube-watch", function () {
		var id = $(this).parent().parent().attr('id');
		window.open("https://www.youtube.com/watch?v="+id);
	});
	$(".top-bar").on("click", ".tab", function () {
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
	videos.height = $(document).height;
	videos.on('DOMNodeInserted', 'div', function () {
		var video = $(this);
		var desc = video.find(".description");
		if (desc.height() > 275) {
			desc.addClass("truncated");
			video.find(".read-more").show();
		} else {
			video.find(".read-more").hide();
		}
		video.find(".read-less").hide();
	});
	videos.on("click", ".read-more", function () {
		var more = $(this);
		more.parent().find(".description").removeClass("truncated");
		more.hide();
		more.parent().find(".read-less").show();
	});
	videos.on("click", ".read-less", function () {
		var less = $(this);
		less.parent().find(".description").addClass("truncated");
		less.hide();
		less.parent().find(".read-more").show();
	});

	displayNoVideos();
});