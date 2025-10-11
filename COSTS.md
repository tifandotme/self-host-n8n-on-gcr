# Cost Analysis

## Setup Overview

- **Platform**: Google Cloud Run (us-west1 region)
- **Allocation**: 1 vCPU, 512Mi RAM (0.5 GiB)
- **Billing**: Instance-based (charged for entire instance lifetime)
- **Database**: Neon PostgreSQL (free tier: 512MB storage, 100 compute hours/month)
- **Exchange Rate**: 1 USD ≈ 16,604.60 Rp (as of latest data)

## Free Tier Details

Cloud Run provides a generous free tier for instance-based billing:

- **CPU**: First 240,000 vCPU-seconds free/month
- **Memory**: First 450,000 GiB-seconds free/month
- **Requests**: 2 million free/month (not applicable for instance-based)
- **Aggregation**: Across all projects in the billing account, resets monthly.
- **Total free value**: ~86,660 Rp/month ($5.22 USD equivalent).

With 1 vCPU and 0.5 GiB allocation:

- Free covers up to ~240,000 seconds (~66.7 hours) of continuous run per month.
- Memory free covers up to ~900,000 seconds, but CPU limits first.

## Cost Calculations

### Rates (us-west1, instance-based)

- CPU: $0.000018 per vCPU-second
- Memory: $0.000002 per GiB-second
- Combined per second: $0.000019 (0.000018 + 0.5 × 0.000002)

### Hypothetical Scenarios

- **24 hours continuous (86,400 seconds)**:
  - vCPU-seconds: 86,400
  - GiB-seconds: 43,200
  - Cost: $1.6416 USD (~27,258 Rp)
  - **Within free tier**: $0 (covered by 240k vCPU-s free)
- **30 days at 24 hours/day**:
  - Total seconds: 2,592,000
  - Cost: ~$49.34 USD (~817,740 Rp) after free tier exhaustion

### Max Usage to Stay Under $24 USD/Month

To keep monthly costs ≤ $24 USD (~398,510 Rp):

- Max billable seconds/month: 1,503,158 (~417.5 hours)
- Max per day (continuous): ~50,105 seconds (~13.9 hours)
- Cost at limit: ~$0.80 USD/day (~13,284 Rp/day)

Exceeding this triggers paid rates (~$0.0684/hour or ~1,136 Rp/hour).

## Comparisons to Alternatives

- **n8n Cloud**: $24/month flat (managed, includes DB). Cheaper for consistent usage; more expensive for variable/low use.
- **Railway**: Free tier for small apps, then $5-20/month. Similar for light use, but base fees apply.
- **AWS (Fargate)**: ~$5-15/month for similar specs. More expensive due to no free tier for variable workloads.
- **Overall**: Cloud Run + Neon is one of the cheapest for personal/low-usage n8n, with pay-per-use and auto-scale-to-zero.

## Tips for Cost Control

- **Monitor Usage**: Use GCP Billing console or Cloud Monitoring for real-time metrics.
- **Optimize Workflows**: Avoid 24/7 runs; use schedulers and scale-to-zero.
- **Free Tier Awareness**: Current usage (~20 minutes/month) is far below limits.
- **Alerts**: Set GCP budget alerts at $20/month.
- **Adjustments**: If needed, reduce CPU/memory in `terraform.tfvars` or switch to request-based billing.
- **CPU Limitations**: CPU <1 vCPU is not supported with `cpu_idle = false` (no throttling). To reduce costs while maintaining performance, lower memory allocation instead (e.g., 512Mi) and keep CPU at 1.

For updates, check GCP pricing and monitor actual usage.
