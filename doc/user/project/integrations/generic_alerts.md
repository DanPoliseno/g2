---
stage: Monitor
group: Health
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#designated-technical-writers
---

# Generic alerts integration

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/13203) in [GitLab Ultimate](https://about.gitlab.com/pricing/) 12.4.
> - [Moved](https://gitlab.com/gitlab-org/gitlab/-/issues/42640) to [GitLab Core](https://about.gitlab.com/pricing/) in 12.8.

GitLab can accept alerts from any source via a generic webhook receiver.
When you set up the generic alerts integration, a unique endpoint will
be created which can receive a payload in JSON format, and will in turn
create an issue with the payload in the body of the issue. You can always
[customize the payload](#customizing-the-payload) to your liking.

The entire payload will be posted in the issue discussion as a comment
authored by the GitLab Alert Bot.

## Setting up generic alerts

To set up the generic alerts integration:

1. Navigate to **Settings > Integrations** in a project.
1. Click on **Alerts endpoint**.
1. Toggle the **Active** alert setting. The `URL` and `Authorization Key` for the webhook configuration can be found there.

## Customizing the payload

You can customize the payload by sending the following parameters. All fields other than `title` are optional:

| Property | Type | Description |
| -------- | ---- | ----------- |
| `title` | String | The title of the incident. Required. |
| `description` | String | A high-level summary of the problem. |
| `start_time` | DateTime | The time of the incident. If none is provided, a timestamp of the issue will be used. |
| `service` | String | The affected service. |
| `monitoring_tool` | String |  The name of the associated monitoring tool. |
| `hosts` | String or Array | One or more hosts, as to where this incident occurred. |
| `severity` | String | The severity of the alert. Must be one of `critical`, `high`, `medium`, `low`, `info`, `unknown`. Default is `critical`. |
| `fingerprint` | String or Array | The unique identifier of the alert. This can be used to group occurrences of the same alert. |

TIP: **Payload size:**
Ensure your requests are smaller than the [payload application limits](../../../administration/instance_limits.md#generic-alert-json-payloads).

Example request:

```shell
curl --request POST \
  --data '{"title": "Incident title"}' \
  --header "Authorization: Bearer <authorization_key>" \
  --header "Content-Type: application/json" \
  <url>
```

The `<authorization_key>` and `<url>` values can be found when [setting up generic alerts](#setting-up-generic-alerts).

Example payload:

```json
{
  "title": "Incident title",
  "description": "Short description of the incident",
  "start_time": "2019-09-12T06:00:55Z",
  "service": "service affected",
  "monitoring_tool": "value",
  "hosts": "value",
  "severity": "high",
  "fingerprint": "d19381d4e8ebca87b55cda6e8eee7385"
}
```
