# Class for JIRA Integration
require 'json'
require 'ipaddr'

class JIRA
  def atlassian
    jira = RestClient::Resource.new(
      "https://#{AppConfig::JIRA.host}",
      user: AppConfig::JIRA.user,
      password: AppConfig::JIRA.password,
      headers: { content_type: 'application/json' },
      verify_ssl: false
    )
  end

  def newissue(project, summary, description, label)
    data = '{
     "fields": {
       "project":
       {
          "key": "'"#{project}"'"
       },
       "summary": "'"#{summary}"'",
       "description": "'"#{description}"'",
       "issuetype": {
          "name": "Story"
       },
       "customfield_10004": 2,
       "labels": [ "'"#{label}"'" ]
     }
    }'
    issue = atlassian['issue']
    response = JSON.parse(issue.post data)
    return response['key']
  end
end
