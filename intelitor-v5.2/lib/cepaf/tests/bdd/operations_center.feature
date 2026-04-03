Feature: Operations Center
  As a Site Reliability Engineer (SRE)
  I want to monitor the runtime health of catalog entities
  So that I can detect drift and outages

  Scenario: Check Kubernetes health
    Given the component "component:default/payment-service" is deployed
    And the deployment has label "backstage.io/kubernetes-id=payment-service"
    When I run the command "sa-k8s pods --entity component:default/payment-service"
    Then the CLI output should list pods
    And the status of "payment-service-xyz" should be "Running"

  Scenario: View latest CI status
    Given "component:default/payment-service" has a GitHub Actions annotation
    When I run the command "sa-ci log component:default/payment-service"
    Then the CLI output should show the latest build status
    And the CLI output should show "Build #123 passed"

  Scenario: Analyze service cost
    Given "component:default/big-data-service" consumes cloud resources
    When I run the command "sa-cost show component:default/big-data-service"
    Then the CLI output should show "Daily Cost: $45.20"
    And the CLI output should show "Trend: Up"

  Scenario: View catalog processing errors
    Given the catalog processor encountered a syntax error in "repo-a"
    When I run the command "sa-catalog errors"
    Then the CLI output should list "repo-a/catalog-info.yaml"
    And the error should be "YAML syntax error"
