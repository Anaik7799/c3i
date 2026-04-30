# /sutra-sdk-test — Run Matrix SDK flow test (FluffyChat simulation)

Run the FluffyChat SDK flow test that replicates the exact login sequence:
1. Ensure server is running on port 6167
2. `cd sub-projects/sutra/matrix_client_test`
3. `LD_LIBRARY_PATH=/nix/store/7qfzpl0v9m4q6z6hnkgl5m0hfcj2nzz7-devenv-profile/lib:$LD_LIBRARY_PATH dart test test/sutra_fluffychat_flow_test.dart -r expanded`
4. Report each step: checkHomeserver, login, sync, uploadKeys, keysQuery, crossSigning
5. If any step fails, check server logs and run /sutra-rca
