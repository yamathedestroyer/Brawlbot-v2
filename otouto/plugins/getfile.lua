-- YOU NEED THE FOLLOWING FOLDERS: photo, document, video, voice
-- PLEASE ADJUST YOUR PATH BELOW

local media_download = {}

media_download.triggers = {
  '/nil'
}

function media_download:download_to_file_permanently(url, save_dir, file_name)
  local respbody = {}
  local options = {
    url = url,
    sink = ltn12.sink.table(respbody),
    redirect = false
  }
  local response = nil
  response = {https.request(options)}
 
  local code = response[2]
  local headers = response[3]
  local status = response[4]

  if code ~= 200 then return false end

  local file_path = save_dir..'/'..file_name
  file = io.open(file_path, "w+")
  file:write(table.concat(respbody))
  file:close()
  print("Downloaded to: "..file_path)
  return true
end

function media_download:pre_process(msg, config)
  if msg.photo then
	local lv = #msg.photo -- find biggest photo, always the last value
    file_id = msg.photo[lv].file_id
	file_size = msg.photo[lv].file_size
  elseif msg.video then
    file_id = msg.video.file_id
	file_size = msg.video.file_size
  elseif msg.sticker then
    file_id = msg.sticker.file_id
	file_size = msg.sticker.file_size
  elseif msg.voice then
    file_id = msg.voice.file_id
	file_size = msg.voice.file_size
  elseif msg.audio then
    file_id = msg.audio.file_id
	file_size = msg.audio.file_size
  elseif msg.document then
    file_id = msg.document.file_id
	file_size = msg.document.file_size
  else
    return msg
  end
  
  if file_size > 19922944 then
    print('File is over 20 MB - can\'t download :(')
	return msg
  end
  
  local save_dir = config.getfile_path
  if not save_dir then
    print('getfile_path not set in config, aborting...')
    return msg
  end
  
  -- Check if file has already been downloaded
  local already_downloaded = redis:sismember('telegram:file_id', file_id)
  if already_downloaded == true then
    print('File has already been downloaded in the past, skipping...')
	return msg
  end
  
  -- Saving file to the Telegram Cloud
  local request = bindings.request('getFile', {
		file_id = file_id
	} )

  -- Getting file from the Telegram Cloud
  if not request then
    print('Download failed!')
	return msg
  end
  
  -- Use original filename for documents
  if msg.document then
    file_path = 'document/'..file_id..'-'..msg.document.file_name -- to not overwrite a file
  else
    file_path = request.result.file_path
  end
  
  -- Construct what we want
  local download_url = 'https://api.telegram.org/file/bot'..config.bot_api_key..'/'..request.result.file_path

  local ok = media_download:download_to_file_permanently(download_url, save_dir, file_path)
  if not ok then
    print('Download failed!')
	return msg
  end
  
  -- Save file_id to redis to prevent downloading the same file over and over when forwarding
  redis:sadd('telegram:file_id', file_id)
  return msg
end

function media_download:action(msg)
end

return media_download
