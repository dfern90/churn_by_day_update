# churn_by_day_update

# Overview

This repository contains SQL scripts to calculate churn rates from subscription data. The process involves creating and populating a `churn_rate_by_day` table, which tracks involuntary churn, voluntary churn, and base churn on a daily basis.

## Features

The main goal of this project is to calculate daily churn rates for subscriptions. Churn rates are categorized into:

- **Involuntary Churn**: Subscriptions that are unpaid.
- **Voluntary Churn**: Subscriptions that are canceled.
- **Base Churn**: Total active subscriptions as of 30 days ago plus new active subscriptions in the last 30 days.
