
# FinOps: Budget & Alerts

# Define a monthly budget of 1 USD for the specific compartment
resource "oci_budget_budget" "crypto_budget" {
  provider              = oci.home
  compartment_id        = var.tenancy_ocid # Budgets are created at the tenancy level
  amount                = 1                # 1 USD limit
  reset_period          = "MONTHLY"
  targets               = [var.compartment_id]
  target_type           = "COMPARTMENT"
  display_name          = "budget-crypto-streaming"
  description           = "Strict 1 USD monthly budget for the crypto platform"
}

# Alert 1: ACTUAL spend reaches 100% of the budget ($1 USD)
resource "oci_budget_alert_rule" "crypto_budget_alert_actual" {
  provider       = oci.home
  budget_id      = oci_budget_budget.crypto_budget.id
  threshold      = 100
  threshold_type = "PERCENTAGE"
  type           = "ACTUAL"
  recipients     = var.alert_email
  message        = "FINOPS ALERT: The crypto streaming platform has reached its actual 1 USD monthly budget."
  display_name   = "alert-actual-crypto-budget"
}

# Alert 2: FORECASTED spend is expected to exceed 100% of the budget
resource "oci_budget_alert_rule" "crypto_budget_alert_forecast" {
  provider       = oci.home
  budget_id      = oci_budget_budget.crypto_budget.id
  threshold      = 100
  threshold_type = "PERCENTAGE"
  type           = "FORECAST"
  recipients     = var.alert_email
  message        = "FINOPS WARNING: The crypto streaming platform is projected to exceed the 1 USD budget this month."
  display_name   = "alert-forecast-crypto-budget"
}