"""Publish a weekly summary of CloudFront request metrics."""

import logging
import math
import os
from datetime import datetime, time, timedelta, timezone

import boto3

LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.INFO)
JAPAN_TIME = timezone(timedelta(hours=9), name="JST")


def report_period(scheduled_time):
    """Return the seven complete Japan-time days before the scheduled run."""
    if not isinstance(scheduled_time, str):
        raise ValueError("The scheduled time is required.")
    scheduled = datetime.fromisoformat(scheduled_time.replace("Z", "+00:00"))
    if scheduled.tzinfo is None:
        raise ValueError("The scheduled time must include a time zone.")
    end_date = scheduled.astimezone(JAPAN_TIME).date()
    end = datetime.combine(end_date, time.min, tzinfo=JAPAN_TIME)
    return end - timedelta(days=7), end


def fetch_daily_requests(client, distribution_id, start, end):
    """Read hourly CloudFront request metrics and sum them by Japan-time day."""
    daily = {start.date() + timedelta(days=day): [] for day in range(7)}
    params = {
        "StartTime": start.astimezone(timezone.utc),
        "EndTime": end.astimezone(timezone.utc),
        "ScanBy": "TimestampAscending",
        "MetricDataQueries": [{
            "Id": "requests",
            "MetricStat": {
                "Metric": {
                    "Namespace": "AWS/CloudFront",
                    "MetricName": "Requests",
                    "Dimensions": [
                        {"Name": "DistributionId", "Value": distribution_id},
                        {"Name": "Region", "Value": "Global"},
                    ],
                },
                "Period": 3600,
                "Stat": "Sum",
            },
            "ReturnData": True,
        }],
    }
    while True:
        response = client.get_metric_data(**params)
        results = response["MetricDataResults"]
        if len(results) != 1 or results[0]["Id"] != "requests":
            raise ValueError("CloudWatch returned an unexpected metric result.")
        result = results[0]
        if result["StatusCode"] not in ("Complete", "PartialData"):
            raise ValueError("CloudWatch did not return a complete request metric.")
        timestamps = result["Timestamps"]
        values = result["Values"]
        if len(timestamps) != len(values):
            raise ValueError("CloudWatch returned mismatched metric data.")
        for timestamp, value in zip(timestamps, values):
            if timestamp.tzinfo is None or not math.isfinite(value) or value < 0:
                raise ValueError("CloudWatch returned an invalid request metric.")
            if not start <= timestamp < end:
                raise ValueError("CloudWatch returned a metric outside the report period.")
            daily[timestamp.astimezone(JAPAN_TIME).date()].append(value)
        token = response.get("NextToken")
        if not token:
            if result["StatusCode"] != "Complete":
                raise ValueError("CloudWatch returned incomplete request metrics.")
            return daily
        params["NextToken"] = token


def format_report(start, end, daily):
    """Format the observed totals and explicitly identify days without data."""
    lines = [
        "CloudFront weekly request report",
        f"Period: {start:%Y-%m-%d %H:%M} to {end:%Y-%m-%d %H:%M} JST (end exclusive)",
        "",
    ]
    for day, values in daily.items():
        count = f"{sum(values):,.0f}" if values else "No metric data"
        lines.append(f"{day:%Y-%m-%d}: {count}")
    observed = [value for values in daily.values() for value in values]
    lines.extend([
        "",
        f"Observed total: {sum(observed):,.0f}" if observed else "Observed total: No metric data",
        "Requests include bots, errors and assets; they are not unique visitors.",
        "Days without metric data are not treated as zero.",
    ])
    return "\n".join(lines)


def lambda_handler(event, context):
    """Fetch the scheduled week's metrics and publish an SNS email."""
    del context
    try:
        start, end = report_period(event.get("scheduled_time"))
        distribution_id = os.environ["DISTRIBUTION_ID"]
        topic_arn = os.environ["TOPIC_ARN"]
        cloudwatch = boto3.client("cloudwatch", region_name="us-east-1")
        sns = boto3.client("sns")
        daily = fetch_daily_requests(cloudwatch, distribution_id, start, end)
        sns.publish(
            TopicArn=topic_arn,
            Subject="Weekly CloudFront request report",
            Message=format_report(start, end, daily),
        )
        LOGGER.info("Published the weekly CloudFront request report.")
        return {"status": "published"}
    except Exception:
        LOGGER.exception("Failed to publish the weekly CloudFront request report.")
        raise
