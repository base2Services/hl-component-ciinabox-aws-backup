CloudFormation do

  tags = external_parameters.fetch(:tags, {})
  
  backup_tags = {}
  backup_tags['Name'] = FnSub("${EnvironmentName}-#{external_parameters[:component_name]}")
  backup_tags['EnvironmentName'] = Ref(:EnvironmentName)

  tags.each {|k,v| backup_tags[k] = FnSub(v)}

  Backup_BackupVault(:BackupVault) do
    BackupVaultName "CiinaboxAWSBackup-BackupVault"
  end

  daily_cron = external_parameters.fetch(:daily_cron, '0 0 * * ? *')
  daily_retention = external_parameters.fetch(:daily_retention, 7)

  Backup_BackupPlan(:BackupPlan) do
    DependsOn :BackupVault
    BackupPlan {
      BackupPlanName "CiinaboxAWSBackup-Plan"
      BackupPlanRule [
        {
          RuleName: "CiinaboxAWSBackup-DailyRule",
          StartWindowMinutes: 60,
          TargetBackupVault: "CiinaboxAWSBackup-BackupVault",
          ScheduleExpression: "cron(#{daily_cron})",
          Lifecycle: {
            DeleteAfterDays: daily_retention
          },
          RecoveryPointTags: {
            "awsbackup:type": "daily"
          }
        }
      ]
    }
    BackupPlanTags backup_tags
  end
  
  Backup_BackupSelection(:BackupSelection) do
    DependsOn :BackupPlan
    BackupPlanId FnGetAtt(:BackupPlan, :BackupPlanId)
    BackupSelection {
      IamRoleArn FnSub("arn:aws:iam::${AWS::AccountId}:role/service-role/AWSBackupDefaultServiceRole")
      ListOfTags [
        {
          ConditionKey: Ref(:CiinaboxTagKey),
          ConditionType: "STRINGEQUALS",
          ConditionValue: Ref(:CiinaboxTagValue)
        }
      ]
      SelectionName "CiinaboxAWSBackup-Selection"
    }
  end


  SNS_Topic(:BackupTopic) do
    TopicName 'Monitoring-CiinaboxAWSBackup-Events'
    Subscription([
      {
        Endpoint: FnJoin('', ['https://api.opsgenie.com/v1/json/cloudwatchevents?apiKey=',Ref(:OpsGenieEventAPIKey)]),
        Protocol: 'HTTPS'
      }
    ])
  end

  Events_Rule(:BackupEvents) do
    DependsOn :BackupTopic
    Description 'Ciinabox Rule for AWS Backup events'
    EventPattern({
      "source": [
        "aws.backup"
      ],
      "detail-type": [
        "AWS API Call via CloudTrail"
      ],
      "detail": {
        "eventName": [
          "BackupJobCompleted"
        ],
        "serviceEventDetails": {
          "state": [
            "ABORTED",
            "FAILED"
          ]
        }
      }
    })
    State "ENABLED"
    Targets([{
      Arn: Ref(:BackupTopic),
      Id: "CiinaboxAwsBackupEvents"
    }])
  end
end