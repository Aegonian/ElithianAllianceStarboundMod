function build(directory, config, parameters, level, seed)
  --Populate the tooltip fields
  config.tooltipFields = config.tooltipFields or {}
  
  local attachmentType = config.theaAttachmentType
  config.tooltipFields.attachmentTypeImage = "/interface/attachmenttypes/"..attachmentType..".png"
  config.tooltipFields.manufacturerLabel = config.manufacturer

  return config, parameters
end
