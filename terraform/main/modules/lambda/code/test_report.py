"""Tests for the weekly CloudFront request report."""

import unittest
from datetime import datetime, timezone
from unittest.mock import Mock, patch

import report


class ReportTests(unittest.TestCase):
    """Verify time windows, metric handling and SNS publication."""

    def setUp(self):
        self.start, self.end = report.report_period("2026-11-02T00:00:00Z")

    def test_period_uses_seven_complete_japan_days(self):
        self.assertEqual(self.start.isoformat(), "2026-10-26T00:00:00+09:00")
        self.assertEqual(self.end.isoformat(), "2026-11-02T00:00:00+09:00")
        with self.assertRaises(ValueError):
            report.report_period("2026-11-02T00:00:00")

    def test_paginates_and_groups_metrics_by_japan_day(self):
        client = Mock()
        client.get_metric_data.side_effect = [
            {"MetricDataResults": [{
                "Id": "requests",
                "StatusCode": "PartialData",
                "Timestamps": [datetime(2026, 10, 25, 15, tzinfo=timezone.utc)],
                "Values": [3.0],
            }], "NextToken": "next"},
            {"MetricDataResults": [{
                "Id": "requests",
                "StatusCode": "Complete",
                "Timestamps": [datetime(2026, 10, 26, 15, tzinfo=timezone.utc)],
                "Values": [7.0],
            }]},
        ]
        daily = report.fetch_daily_requests(client, "EDIST", self.start, self.end)
        self.assertEqual(list(daily.values())[:2], [[3.0], [7.0]])
        self.assertEqual(client.get_metric_data.call_args_list[1].kwargs["NextToken"], "next")
        query = client.get_metric_data.call_args_list[0].kwargs["MetricDataQueries"][0]
        self.assertEqual(query["MetricStat"]["Metric"]["Dimensions"], [
            {"Name": "DistributionId", "Value": "EDIST"},
            {"Name": "Region", "Value": "Global"},
        ])
        text = report.format_report(self.start, self.end, daily)
        self.assertIn("Observed total: 10", text)
        self.assertIn("2026-10-28: No metric data", text)

    def test_no_data_is_not_reported_as_zero(self):
        client = Mock()
        client.get_metric_data.return_value = {"MetricDataResults": [{
            "Id": "requests", "StatusCode": "Complete", "Timestamps": [], "Values": [],
        }]}
        daily = report.fetch_daily_requests(client, "EDIST", self.start, self.end)
        self.assertIn("Observed total: No metric data", report.format_report(self.start, self.end, daily))

    def test_incomplete_or_invalid_metrics_raise(self):
        client = Mock()
        client.get_metric_data.return_value = {"MetricDataResults": [{
            "Id": "requests", "StatusCode": "PartialData", "Timestamps": [], "Values": [],
        }]}
        with self.assertRaisesRegex(ValueError, "incomplete"):
            report.fetch_daily_requests(client, "EDIST", self.start, self.end)
        client.get_metric_data.return_value = {"MetricDataResults": [{
            "Id": "requests", "StatusCode": "Complete",
            "Timestamps": [datetime(2026, 11, 3, tzinfo=timezone.utc)], "Values": [1.0],
        }]}
        with self.assertRaisesRegex(ValueError, "outside"):
            report.fetch_daily_requests(client, "EDIST", self.start, self.end)

    @patch.dict("os.environ", {"DISTRIBUTION_ID": "EDIST", "TOPIC_ARN": "topic"})
    @patch("report.boto3.client")
    def test_handler_publishes_and_propagates_sns_failures(self, boto_client):
        cloudwatch, sns = Mock(), Mock()
        cloudwatch.get_metric_data.return_value = {"MetricDataResults": [{
            "Id": "requests", "StatusCode": "Complete", "Timestamps": [], "Values": [],
        }]}
        boto_client.side_effect = [cloudwatch, sns, cloudwatch, sns]
        event = {"scheduled_time": "2026-11-02T00:00:00Z"}
        self.assertEqual(report.lambda_handler(event, None), {"status": "published"})
        boto_client.assert_any_call("cloudwatch", region_name="us-east-1")
        self.assertEqual(sns.publish.call_args.kwargs["TopicArn"], "topic")
        sns.publish.side_effect = RuntimeError("SNS unavailable")
        with self.assertLogs("report", level="ERROR"):
            with self.assertRaisesRegex(RuntimeError, "SNS unavailable"):
                report.lambda_handler(event, None)


if __name__ == "__main__":
    unittest.main()
