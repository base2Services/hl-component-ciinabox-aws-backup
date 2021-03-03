CfhighlanderTemplate do
  Name 'ciinabox-aws-backup'
  Description "ciinabox-aws-backup - #{component_version}"

  Parameters do
    ComponentParam 'EnvironmentName', 'dev', isGlobal: true
    ComponentParam 'EnvironmentType', 'development', allowedValues: ['development','production'], isGlobal: true
    ComponentParam 'OpsGenieEventAPIKey'
    ComponentParam 'CiinaboxTagKey', 'Name'
    ComponentParam 'CiinaboxTagValue'
  end


end
