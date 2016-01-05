current_version = JSON.parse(localStorage.getItem('version')) or 0

version = 1
if current_version < version
  localStorage.removeItem('video-filter')
  localStorage.removeItem('unwatched-videos')
  localStorage.removeItem('watched-videos')
  localStorage.removeItem('blocked-videos')

  localStorage.setItem('version', version)


