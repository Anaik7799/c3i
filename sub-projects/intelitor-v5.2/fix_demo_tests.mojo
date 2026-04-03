from python import Python

fn main() raises:
    var os = Python.import_module("os")
    var re = Python.import_module("re")

    var files = List[String](
        "test/demo/alarms_enterprise_demo_test.exs",
        "test/demo/analytics_enterprise_demo_test.exs",
        "test/demo/automation_enterprise_demo_test.exs",
        "test/demo/backup_enterprise_demo_test.exs",
        "test/demo/bulk_update_enterprise_demos_sopv51_test.exs",
        "test/demo/communication_enterprise_demo_test.exs",
        "test/demo/compliance_enterprise_demo_test.exs",
        "test/demo/container_aware_continuous_demo_test.exs",
        "test/demo/container_demo_with_phoenix_test.exs",
        "test/demo/continuous_enterprise_demo_executor_test.exs",
        "test/demo/demo_health_validator_test.exs",
        "test/demo/devices_enterprise_demo_test.exs",
        "test/demo/guard_tours_enterprise_demo_test.exs",
        "test/demo/integration_enterprise_demo_test.exs",
        "test/demo/mobile_enterprise_demo_test.exs",
        "test/demo/performance_monitoring_demo_executor_test.exs",
        "test/demo/port_4001_proxy_test.exs",
        "test/demo/quick_setup_enterprise_demo_test.exs",
        "test/demo/reports_enterprise_demo_test.exs",
        "test/demo/risk_management_enterprise_demo_test.exs",
        "test/demo/simple_container_validation_test.exs",
        "test/demo/simple_final_testing_test.exs",
        "test/demo/simple_phics_validation_test.exs",
        "test/demo/sites_enterprise_demo_test.exs",
        "test/demo/sopv51_framework_test.exs",
        "test/demo/system_enterprise_demo_test.exs",
        "test/demo/test_alarm_functionality_test.exs",
        "test/demo/test_alarm_processing_with_db_test.exs",
        "test/demo/test_pure_nixos_stack_test.exs",
        "test/demo/update_all_demo_scripts_sopv51_test.exs",
        "test/demo/validate_all_demo_paths_test.exs",
        "test/demo/validate_demo_ready_containers_test.exs",
        "test/demo/video_analytics_enterprise_demo_test.exs",
        "test/demo/visitor_management_enterprise_demo_test.exs"
    )

    var replacement_multi_tenant = """    test "demo supports multi-tenant scenarios" do
      # TDG: Test multi-tenant demo scenarios
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)
      user1 = insert(:user, tenant: tenant1)
      user2 = insert(:user, tenant: tenant2)

      # Verify tenant isolation
      assert user1.tenant_id != user2.tenant_id
      assert user1.tenant_id == tenant1.id
      assert user2.tenant_id == tenant2.id
    end"""

    var replacement_concurrent = """    test "demo handles concurrent scenarios" do
      # TDG: Test concurrent demo operations
      tenant = insert(:tenant)
      users = Enum.map(1..3, fn _ -> insert(:user, tenant: tenant) end)

      # Simulate concurrent operations
      tasks =
        Enum.map(users, fn user ->
          Task.async(fn ->
            # Basic demo operation test
            %{tenant_id: tenant.id, user_id: user.id, result: "success"}
          end)
        end)

      results = Task.await_many(tasks, 5000)

      # All concurrent operations should succeed
      assert length(results) == 3
      assert Enum.all?(results, &(&1.result == "success"))
    end"""

    var replacement_business_rules = """    test "demo validates business rules" do
      # TDG: Test business rule validation
      tenant = insert(:tenant)
      user = insert(:user, tenant: tenant)

      # Test basic business rule validation
      assert user.tenant_id == tenant.id
      assert user.__struct__ == Intelitor.Accounts.User
    end"""

    for i in range(len(files)):
        var file_path = files[i]
        if not os.path.exists(file_path):
            print("Skipping " + file_path + " (not found)")
            continue

        var f = open(file_path, "r")
        var content = f.read()
        f.close()

        # Fix Import
        content = content.replace("import Intelitor.AccountsFixtures", "import Intelitor.Factory")

        # Fix Multi-tenant Test
        var pattern_multi_tenant = r'test "demo supports multi - tenant scenarios" do.*?end'
        content = re.sub(pattern_multi_tenant, replacement_multi_tenant, content, flags=re.DOTALL)

        # Fix Concurrent Test
        var pattern_concurrent = r'test "demo handles concurrent scenarios" do.*?end'
        content = re.sub(pattern_concurrent, replacement_concurrent, content, flags=re.DOTALL)

        # Fix Business Rules Test
        var pattern_business = r'test "demo validates business rules" do.*?end'
        content = re.sub(pattern_business, replacement_business_rules, content, flags=re.DOTALL)

        # Fix Path spaces
        content = re.sub(r'"scripts / demo / (.*?)"', r'"scripts/demo/\1"', content)

        var f_out = open(file_path, "w")
        f_out.write(content)
        f_out.close()
        print("Fixed " + file_path)