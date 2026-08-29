# Changes
## 0.1.5
- feat: blacklist nodes after repeated connect failures — after
  `connect_failure_threshold` consecutive failures (default 5) a node is
  skipped for `blacklist_retry_interval` (default 1 minute), then probed
  again; stops re-dialing unreachable/foreign-cookie nodes every poll cycle
- fix: replace deprecated Logger.warn calls
- fix: replace broken placeholder test with real Blacklist unit tests

## 0.1.4
- fix: describe instances still returning terminated instances

## 0.1.3
- update xml2map

## 0.1.2
- fix: make sure we don't error on :net_adm errors and log better

## 0.1.1
- Allow current_node_in_tag? to do a partial match on the start of a string
- Add config to release files

## 0.1.0
- Initial Release
