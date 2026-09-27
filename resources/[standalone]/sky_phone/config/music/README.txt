Place server-owned .mp3 and .ogg files in this directory.

In ../music.lua, register only Id, Title and Artist. The resource searches this
directory and every subdirectory for files whose name matches the Id. Example:

    Tracks = {
        { Id = "night-drive", Title = "Night Drive", Artist = "Sky Records" },
    }

The entry above finds, for example:

    config/music/electronic/night-drive.ogg
    config/music/electronic/covers/night-drive.webp

Audio must be named <Id>.ogg or <Id>.mp3. Artwork is optional and must be named
<Id>.webp, <Id>.png, <Id>.jpg or <Id>.jpeg. If multiple formats exist, OGG is
preferred over MP3; artwork priority is WEBP, PNG, JPG, then JPEG. Do not place
the same preferred extension for one Id in multiple folders.

Matching is case-insensitive, but keep Id spelling stable because saved
playlists reference it. Folder names may contain spaces, but must not contain
path separators or control characters. Do not give a folder an audio or artwork
extension. Restart the sky_phone resource after changing tracks or files; a
frontend build is not required.

Upgrading from the old path-based setup: rename each audio and artwork file to
its existing Id, then remove File and Artwork from the track entry. Do not
change the Id itself.
