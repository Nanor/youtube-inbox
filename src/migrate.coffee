migrations = [
  () ->
    localStorage.removeItem('video-filter')
    localStorage.removeItem('unwatched-videos')
    localStorage.removeItem('watched-videos')
    localStorage.removeItem('blocked-videos')
  () ->
    localStorage.removeItem('expand')
]

currentVersion = JSON.parse(localStorage.getItem('version')) or 0

for migration, version in migrations
  if currentVersion <= version
    migration()
    currentVersion = version + 1

localStorage.setItem('version', currentVersion)

