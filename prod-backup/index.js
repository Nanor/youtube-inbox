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
	
	function loadVideo(data) {
		if (data.responseData !== null) {
			$.each(data.responseData.feed.entries, function (i, e) {
				var video = {
					title: e.title,
					link: e.link.split("=")[1],
					author: e.author,
					publishedDate: e.publishedDate,
					contentSnippet: e.contentSnippet,
					content: e.content,
					catagories: e.catagories,
				};
//				if (new Date(video.publishedDate).getTime() < (new Date().getTime() - 1000 * 60 * 60 * 24)) {
				if (uncheckedWatched.indexOf(video.link) !== -1) {
					watchedVideos.push(video.link);
				}
				videos.push(video);
				needsUpdate = 10;
			});
		}
	}
		
//	$.ajax({
//		url: "subscription_manager.xml",
//		dataType: "xml",
//		success: function (data) {
	var xmlString = '<opml version="1.1"><body><outline text="YouTube Subscriptions" title="YouTube Subscriptions"><outline text="Markiplier" title="Markiplier" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC7_YxT-KID8kRbqZo7MyscQ" /><outline text="Freeze ME" title="Freeze ME" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCHs56pMIotQ-ubY6xAPuA8w" /><outline text="RetroSpecter" title="RetroSpecter" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC8H0nNZJfP4zYpuvdl_4AeA" /><outline text="TheSmashToons" title="TheSmashToons" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCZ2xKWvrEPziMOi__LjB9CQ" /><outline text="Fratocrats" title="Fratocrats" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCi1ItEw8XoEOFASMaP0meeQ" /><outline text="mmm... Lemony Fresh" title="mmm... Lemony Fresh" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCo7AZGZl2NBroPPfaNDzg3Q" /><outline text="CatFat" title="CatFat" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC7IrdWm-HpdQAs3TuUpC1zQ" /><outline text="The World Of Steven Universe" title="The World Of Steven Universe" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCQ_8L__82Wul4u3H-HGHUbA" /><outline text="Master Sword" title="Master Sword" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCAeDC-kFK69W87jQu7RmxSA" /><outline text="Artsy Omni" title="Artsy Omni" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCI9d6eQjf__r5gyH4GHRssg" /><outline text="The Storyteller\'s Box" title="The Storyteller\'s Box" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCJanyxJht19fhuTGtJfumyg" /><outline text="pixlpit" title="pixlpit" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCscCSZoK3BknJKSZry17JiQ" /><outline text="Ace Waters" title="Ace Waters" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCUqCvRYlQy02gULC5GAupQQ" /><outline text="Penniless Ragamuffin" title="Penniless Ragamuffin" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCgb_W03rSNRau2BBr1wUDDQ" /><outline text="Grant Kirkhope" title="Grant Kirkhope" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCqGXr8Gf1eY8AsnLlKlgQYw" /><outline text="GameGrumps" title="GameGrumps" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC9CuvdOVfMPvKCiwdGKL3cQ" /><outline text="Benjamin Briggs" title="Benjamin Briggs" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCRC_MIZGejtGSsM8AE6GNwQ" /><outline text="Welcome to Night Vale" title="Welcome to Night Vale" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCrvuY59InDI3iKvopKT8PEw" /><outline text="Brandon Turner" title="Brandon Turner" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCXRyXeR2PrS2NXFVh9LvetQ" /><outline text="TheMysteryofGF" title="TheMysteryofGF" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC38Qv_0pYEdw8WL2MClJKtA" /><outline text="KittyKatGaming" title="KittyKatGaming" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCzHWMl59l72-lZQDA0uW8yg" /><outline text="Numberphile2" title="Numberphile2" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCyp1gCHZJU_fGWFf2rtMkCg" /><outline text="aivi &amp; surasshu" title="aivi &amp; surasshu" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC4t11MCqFSm6HJHihark9sw" /><outline text="Aivi Tran" title="Aivi Tran" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCeI36oi8XyXPD1Lq_vuL73Q" /><outline text="Cards Against Humanity" title="Cards Against Humanity" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCnDUXHgKYa5j-7p-2VfHL3A" /><outline text="GrumpOut" title="GrumpOut" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCAQ0o3l-H3y_n56C3yJ9EHA" /><outline text="BAHFest" title="BAHFest" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC9v7v79mAlvKCrjrJvj-Fww" /><outline text="Hello Internet" title="Hello Internet" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCwez9XDNV_wS0WNDZteXjgw" /><outline text="LastWeekTonight" title="LastWeekTonight" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC3XTzVzaHQEd30rQbuvCtTQ" /><outline text="GamesWithHank" title="GamesWithHank" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCyxcGxSCgN4L02rdXqaATug" /><outline text="TomSka" title="TomSka" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCOYWgypDktXdb-HfZnSMK6A" /><outline text="Domics" title="Domics" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCn1XB-jvmd9fXMzhiA6IR0w" /><outline text="Playtonic Games" title="Playtonic Games" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCueKkTDzpAUAof825AsGZtQ" /><outline text="moviebob" title="moviebob" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCy92fXa6yBrLnKdW1pYJlMw" /><outline text="ExplosmEntertainment" title="ExplosmEntertainment" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCWXCrItCF6ZgXrdozUS-Idw" /><outline text="WheezyWaiter" title="WheezyWaiter" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCQL5ABUvwY7YoW5lgMyAS_w" /><outline text="vlogbrothers" title="vlogbrothers" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCGaVdbSav8xWuFWTadK6loA" /><outline text="Element Animation" title="Element Animation" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC0AE_22J0kAo30yjasaeFqw" /><outline text="Healthcare Triage" title="Healthcare Triage" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCabaQPYxxKepWUsEVQMT4Kw" /><outline text="Tom Scott" title="Tom Scott" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCBa659QWEk1AI4Tg--mrJ2A" /><outline text="Numberphile" title="Numberphile" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCoxcjq-8xIDTYp3uz647V5A" /><outline text="5secondfilms" title="5secondfilms" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCG9lNhVqk9luFLxBKDzuO9g" /><outline text="CartoonHangover" title="CartoonHangover" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCIA9jUDnKVMYc4SmqTxcwqg" /><outline text="PBS Idea Channel" title="PBS Idea Channel" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC3LqW4ijMoENQ2Wv17ZrFJA" /><outline text="Extra Credits" title="Extra Credits" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCCODtTcd5M1JavPCOr_Uydg" /><outline text="direwolf20" title="direwolf20" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC_ViSsVg_3JUDyLS3E2Un5g" /><outline text="Atpunk" title="Atpunk" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCZNFPjN3ELUM4EkNPhLM1Pg" /><outline text="Dean Dobbs" title="Dean Dobbs" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCrqjpBWvShA9WLGKDlzGe2w" /><outline text="PlayerPiano" title="PlayerPiano" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCAIwH4ubfkRWep6ZkmRG8Gg" /><outline text="MC Frontalot" title="MC Frontalot" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC74196V9042vIRs5sDcRHPg" /><outline text="Harry101UK" title="Harry101UK" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCUJXm3LMFLSEe_A2IBf8GwQ" /><outline text="Ninja Sex Party" title="Ninja Sex Party" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCs7yDP7KWrh0wd_4qbDP32g" /><outline text="Egoraptor" title="Egoraptor" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC0gEw6pgNkLkkzMwzX4UtHA" /><outline text="Paul ter Voorde" title="Paul ter Voorde" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC64hJxa5uM3P_KusfYc-CWw" /><outline text="Rhett &amp; Link" title="Rhett &amp; Link" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCbochVIwBCzJb9I2lLGXGjQ" /><outline text="How to Adult" title="How to Adult" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCFqaprvZ2K5JOULCvr18NTQ" /><outline text="Veritasium" title="Veritasium" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCHnyfMqiRRG1u-2MsSQLbXA" /><outline text="SciShow Space" title="SciShow Space" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCrMePiHCWG4Vwqv3t7W9EFg" /><outline text="JonTronShow" title="JonTronShow" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCdJdEguB1F1CiYe7OEi3SBg" /><outline text="DidYouKnowGaming?" title="DidYouKnowGaming?" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCyS4xQE6DK4_p3qXQwJQAyA" /><outline text="New Game Plus" title="New Game Plus" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCqu_RCsGiswUlSWS6HsCVFQ" /><outline text="Doctor Who" title="Doctor Who" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCcOkA2Xmk1valTOWSyKyp4g" /><outline text="JackHoward" title="JackHoward" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCc-2O0_cKAWGQEuHqHHh3GA" /><outline text="Vsauce" title="Vsauce" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC6nSFpj9HTCZ5t-N3Rm3-HA" /><outline text="Christopher Niosi" title="Christopher Niosi" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCKnUnMncnZ7zHxtxBNzdvaA" /><outline text="Sonic For Hire" title="Sonic For Hire" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=SW8udTMcfcKX0" /><outline text="HuHa 2!" title="HuHa 2!" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCkHj8YHppqA89ajNHRKJA5Q" /><outline text="TomPreston6" title="TomPreston6" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCkmurtukCO_adXHmxiVz6gw" /><outline text="ScottFalco" title="ScottFalco" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCxjs86jJMMa3Mhxt8KThsYA" /><outline text="Dani Jones" title="Dani Jones" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCPtB63hrAAZWB6xnUIKkGtQ" /><outline text="CraftedBonus" title="CraftedBonus" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCnidU2BkALEtVdrNUOdnlvA" /><outline text="Element Animation 2" title="Element Animation 2" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC4Y6bt3nixoEi-KngirFEvA" /><outline text="samandniko" title="samandniko" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCSpFnDQr88xCZ80N-X7t0nQ" /><outline text="Little Kuriboh" title="Little Kuriboh" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCZzXTv6tbD_VVwcaUuu8rFw" /><outline text="LittleKuriboh" title="LittleKuriboh" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC2NU0s1H0p9N4jvF7qV59vA" /><outline text="Tim H" title="Tim H" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCkxA_F2rjRprjCDgjbwBT6Q" /><outline text="Simon\'s Cat" title="Simon\'s Cat" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCH6vXjt-BA7QHl0KnfL-7RQ" /><outline text="Cat Face" title="Cat Face" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCl3qc8AmupICnNfPspY6y9w" /><outline text="simonscatextra" title="simonscatextra" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCE3pZOwArJXDOQjcQsiQT_w" /><outline text="Eddsworld" title="Eddsworld" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCSS6UvWXW8OZD9wpIVkD0YA" /><outline text="SMBC Theater" title="SMBC Theater" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCVtt6C8Qu_ia7g2l80sY2kQ" /><outline text="Element Shorts" title="Element Shorts" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCHSbcpM4V2ulBQPPiFVdO-Q" /><outline text="Slamacow" title="Slamacow" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCCuIq8gvVXGUe00Bti3uv9w" /><outline text="Jack &amp; Dean" title="Jack &amp; Dean" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCpjhI-0FBMao7jSuafXuEjA" /><outline text="BrandonJLa" title="BrandonJLa" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC7XQ-N5zRR6hG07urYrK7Aw" /><outline text="Geek &amp; Sundry" title="Geek &amp; Sundry" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCaBf1a-dpIsw8OxqH4ki2Kg" /><outline text="CraftedMovie" title="CraftedMovie" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCfvssu5wvOX5vPHruFHxaJw" /><outline text="loadingreadyrun" title="loadingreadyrun" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCwjN2uVdL9A0i3gaIHKFzuA" /><outline text="BravestWarriors" title="BravestWarriors" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCumX61u3NGG7HcBTnnWmzRg" /><outline text="RocketJump" title="RocketJump" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCDsO-0Yo5zpJk575nKXgMVA" /><outline text="DarkSquidge" title="DarkSquidge" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC3tMH8u6yG3mSxi-qpfmpkA" /><outline text="EsquirebobAnimations" title="EsquirebobAnimations" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCohKave7-7Ixs1TxJtFEsog" /><outline text="Guy Collins Animation" title="Guy Collins Animation" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC0n7hqQFFEZnwxrcVh09uVA" /><outline text="Improv Everywhere" title="Improv Everywhere" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCTrtA2LyW7gie0o8hY4efXw" /><outline text="Matt Lobster" title="Matt Lobster" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCFU-IQMFo1uXyXazYUG2d6Q" /><outline text="CartoonHangover2" title="CartoonHangover2" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCl3sF4HTQo7djPAxjt0juBA" /><outline text="Harry Partridge" title="Harry Partridge" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCir4goG7LBQCh5rc3frkHuA" /><outline text="CorridorDigital" title="CorridorDigital" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCsn6cjffsvyOZCZxvGoJxGg" /><outline text="RubberNinja" title="RubberNinja" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCsW0LA-ThH18OCrT9pa2zfQ" /><outline text="Vsauce3" title="Vsauce3" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCwmFOfFuvRPI112vR5DNnrA" /><outline text="quill18creates" title="quill18creates" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCPXOQq7PWh5OdCwEO60Y8jQ" /><outline text="feministfrequency" title="feministfrequency" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC7Edgk9RxP7Fm7vjQ1d-cDA" /><outline text="VPPlaysGames" title="VPPlaysGames" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCm9tv-1wHzGrptIW8Ek4rhQ" /><outline text="vihartvihart" title="vihartvihart" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCt3QIly_CdcnTtau_7xD5sA" /><outline text="Vihart" title="Vihart" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCOGeU-1Fig3rrDjhm9Zs_wg" /><outline text="VerbalProcessing" title="VerbalProcessing" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCZCfUfBWr1auoWV3qkfP6mQ" /><outline text="Valve" title="Valve" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCg0FSqPeiGD_lIiPaaAehQg" /><outline text="Tim Minchin" title="Tim Minchin" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCz5wnzqxdlrhdpaVoRwKe2A" /><outline text="TheSpanglerEffect" title="TheSpanglerEffect" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC6sWKVFVfuyTk0FTPY4c62Q" /><outline text="themusicman1993" title="themusicman1993" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCvJ-EpQthcSfxFL982hQK8A" /><outline text="The Synthetic Orchestra" title="The Synthetic Orchestra" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCQOm3j7QTQqAJVCyiCNOXBA" /><outline text="The Informal Synthetic Orchestra" title="The Informal Synthetic Orchestra" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCVpyHwrk9IZqIdszvv8Mc6A" /><outline text="The Giza Necropolis Project" title="The Giza Necropolis Project" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCI4Qs3Qi92B7qiXjoPKkevw" /><outline text="StackHQ" title="StackHQ" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UChcPvcyuPKfHRmHeSw5j1Kw" /><outline text="SomethingCubedVideos" title="SomethingCubedVideos" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCHvYYAPkfcYOEC4cGJ1FbQQ" /><outline text="Slamacow Steven" title="Slamacow Steven" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCg2-gFDsbzULwd89QctOn3g" /><outline text="SciShow" title="SciShow" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCZYTClx2T1of7BRZ86-8fow" /><outline text="PoopPoopFart" title="PoopPoopFart" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCohllq0Pk5lQuuNANabHKcg" /><outline text="pennyarcadeTV" title="pennyarcadeTV" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCTlOYZOU1HGEqgb2XetyBBQ" /><outline text="ObeyMyRod" title="ObeyMyRod" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCtgJiaJ0hFS-T4dZRybdXwA" /><outline text="Ninjabridge" title="Ninjabridge" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC6A33q8SpqYbyeF0GARRruQ" /><outline text="Nerf Now!!" title="Nerf Now!!" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC06YOS4yBuaeOCJvW0At1CA" /><outline text="MinuteEarth" title="MinuteEarth" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCeiYXex_fwgYDonaTcSIk6w" /><outline text="minutephysics" title="minutephysics" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCUHW94eEFW7hkUMVaZz4eDg" /><outline text="HuHa!" title="HuHa!" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCr9wK9o3IGJjAyDtNsQddCQ" /><outline text="hankschannel" title="hankschannel" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCOT2iLov0V7Re7ku_3UBtcQ" /><outline text="GnomeSlice" title="GnomeSlice" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCqLzEn7aTw8VsBGJ2-2FlAw" /><outline text="GamingSE" title="GamingSE" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCTIXKddQdXHbLcxRp5os6Ug" /><outline text="FallenAngelEyes" title="FallenAngelEyes" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCCAXhom6UlMu8LcH-anxALQ" /><outline text="Dig Build Live" title="Dig Build Live" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCvsGYHlUw0Ybw4W0JHLVQqw" /><outline text="DemonTomatoDave" title="DemonTomatoDave" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCZn2JQsQd3MXH07aI9TDI3g" /><outline text="David Mitchell\'s Soapbox" title="David Mitchell\'s Soapbox" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCtxNu_ADBcbujQh-s9OBFvQ" /><outline text="collectedcurios" title="collectedcurios" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCxKI_7cnPY3rcKVHCQu3EdA" /><outline text="CGP Grey" title="CGP Grey" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC2C_jShtL725hvbm1arSV9w" /><outline text="brokeeats" title="brokeeats" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCtFUri9ZA630XW9qdnH_65w" /><outline text="Blondjonesy" title="Blondjonesy" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCg6xGbo6y8g_ciLt1Y6Tudw" /><outline text="badp" title="badp" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCOgbZIIzbE4eXiKnf7dUxwQ" /><outline text="At God" title="At God" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCGDA0tIVPInDXzAKErWM0cw" /><outline text="ArqadeCommunity" title="ArqadeCommunity" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC96ee06Fgp2Uce2ezHHospQ" /><outline text="Kerbal Space Program" title="Kerbal Space Program" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC-ZlXbhKDI6m0IQGGSNvtaw" /><outline text="The Good Stuff" title="The Good Stuff" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCxu3mVAacTdrLPfwTsAEUzg" /><outline text="Smooth McGroove" title="Smooth McGroove" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCJvBEEqTaLaKclbCPgIjBSQ" /><outline text="Joe Jeremiah" title="Joe Jeremiah" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCVUADDzjYdnGJTuEdUcRt9g" /><outline text="I Fight Dragons" title="I Fight Dragons" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCHDUUx4O16LqWyJyZ8000RA" /><outline text="MINIMI95020" title="MINIMI95020" type="rss" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCKG7_ZBGyD9LQtd_E0YYtug" /></outline></body></opml>';
		var data = $.parseXML(xmlString);
			var outlines = data.getElementsByTagName("outline");

			for (var i = 0; i < outlines.length; i++) {
				var url = outlines[i].getAttribute("xmlUrl");

				if (url !== null) {
					$.ajax({
						url: 'http://ajax.googleapis.com/ajax/services/feed/load?v=1.0&num=10&callback=?&q=' + encodeURIComponent(url),
						dataType: 'json',
						success: loadVideo
					});
				}
			}
//		}
//	});
	
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
			'<p class="author">by '+video.author+'</p>'+
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
	
	readData();
	displayNoVideos();
});