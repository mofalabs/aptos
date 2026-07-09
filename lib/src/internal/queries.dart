/// The GraphQL query documents used by the indexer-backed functions.
///
/// Constants are named after their GraphQL operation names in lowerCamelCase;
/// fragments are inlined via constant string concatenation.
///
/// Only the queries actually used by the implemented functions are included.
library;

/// The `TokenActivitiesFields` fragment on `token_activities_v2`.
const String tokenActivitiesFieldsFragment = r'''
    fragment TokenActivitiesFields on token_activities_v2 {
  after_value
  before_value
  entry_function_id_str
  event_account_address
  event_index
  from_address
  is_fungible_v2
  property_version_v1
  to_address
  token_amount
  token_data_id
  token_standard
  transaction_timestamp
  transaction_version
  type
}
    ''';

/// The `AnsTokenFragment` fragment on `current_aptos_names`.
const String ansTokenFragment = r'''
    fragment AnsTokenFragment on current_aptos_names {
  domain
  expiration_timestamp
  registered_address
  subdomain
  token_standard
  is_primary
  owner_address
  subdomain_expiration_policy
  domain_expiration_timestamp
}
    ''';

/// The `CurrentTokenOwnershipFields` fragment on
/// `current_token_ownerships_v2`.
const String currentTokenOwnershipFieldsFragment = r'''
    fragment CurrentTokenOwnershipFields on current_token_ownerships_v2 {
  token_standard
  token_properties_mutated_v1
  token_data_id
  table_type_v1
  storage_id
  property_version_v1
  owner_address
  last_transaction_version
  last_transaction_timestamp
  is_soulbound_v2
  is_fungible_v2
  amount
  current_token_data {
    collection_id
    description
    is_fungible_v2
    largest_property_version_v1
    last_transaction_timestamp
    last_transaction_version
    maximum
    supply
    token_data_id
    token_name
    token_properties
    token_standard
    token_uri
    decimals
    current_collection {
      collection_id
      collection_name
      creator_address
      current_supply
      description
      last_transaction_timestamp
      last_transaction_version
      max_supply
      mutable_description
      mutable_uri
      table_handle_v1
      token_standard
      total_minted_v2
      uri
    }
  }
}
    ''';

const String getAccountAddressesForAuthKey = r'''
    query getAccountAddressesForAuthKey($where_condition: auth_key_account_addresses_bool_exp, $order_by: [auth_key_account_addresses_order_by!]) {
  auth_key_account_addresses(where: $where_condition, order_by: $order_by) {
    auth_key
    account_address
    last_transaction_version
    is_auth_key_used
  }
}
    ''';

const String getAccountCoinsCount = r'''
    query getAccountCoinsCount($address: String) {
  current_fungible_asset_balances_aggregate(
    where: {owner_address: {_eq: $address}}
  ) {
    aggregate {
      count
    }
  }
}
    ''';

const String getAccountCoinsData = r'''
    query getAccountCoinsData($where_condition: current_fungible_asset_balances_bool_exp!, $offset: Int, $limit: Int, $order_by: [current_fungible_asset_balances_order_by!]) {
  current_fungible_asset_balances(
    where: $where_condition
    offset: $offset
    limit: $limit
    order_by: $order_by
  ) {
    amount
    asset_type
    is_frozen
    is_primary
    last_transaction_timestamp
    last_transaction_version
    owner_address
    storage_id
    token_standard
    metadata {
      token_standard
      symbol
      supply_aggregator_table_key_v1
      supply_aggregator_table_handle_v1
      project_uri
      name
      last_transaction_version
      last_transaction_timestamp
      icon_uri
      decimals
      creator_address
      asset_type
    }
  }
}
    ''';

const String getAccountCollectionsWithOwnedTokens = r'''
    query getAccountCollectionsWithOwnedTokens($where_condition: current_collection_ownership_v2_view_bool_exp!, $offset: Int, $limit: Int, $order_by: [current_collection_ownership_v2_view_order_by!]) {
  current_collection_ownership_v2_view(
    where: $where_condition
    offset: $offset
    limit: $limit
    order_by: $order_by
  ) {
    current_collection {
      collection_id
      collection_name
      creator_address
      current_supply
      description
      last_transaction_timestamp
      last_transaction_version
      mutable_description
      max_supply
      mutable_uri
      table_handle_v1
      token_standard
      total_minted_v2
      uri
    }
    collection_id
    collection_name
    collection_uri
    creator_address
    distinct_tokens
    last_transaction_version
    owner_address
    single_token_uri
  }
}
    ''';

const String getAccountOwnedTokens = r'''
    query getAccountOwnedTokens($where_condition: current_token_ownerships_v2_bool_exp!, $offset: Int, $limit: Int, $order_by: [current_token_ownerships_v2_order_by!]) {
  current_token_ownerships_v2(
    where: $where_condition
    offset: $offset
    limit: $limit
    order_by: $order_by
  ) {
    ...CurrentTokenOwnershipFields
  }
}
    ''' +
    currentTokenOwnershipFieldsFragment;

const String getAccountOwnedTokensFromCollection = r'''
    query getAccountOwnedTokensFromCollection($where_condition: current_token_ownerships_v2_bool_exp!, $offset: Int, $limit: Int, $order_by: [current_token_ownerships_v2_order_by!]) {
  current_token_ownerships_v2(
    where: $where_condition
    offset: $offset
    limit: $limit
    order_by: $order_by
  ) {
    ...CurrentTokenOwnershipFields
  }
}
    ''' +
    currentTokenOwnershipFieldsFragment;

const String getAccountTokensCount = r'''
    query getAccountTokensCount($where_condition: current_token_ownerships_v2_bool_exp, $offset: Int, $limit: Int) {
  current_token_ownerships_v2_aggregate(
    where: $where_condition
    offset: $offset
    limit: $limit
  ) {
    aggregate {
      count
    }
  }
}
    ''';

const String getAccountTransactionsCount = r'''
    query getAccountTransactionsCount($address: String) {
  account_transactions_aggregate(where: {account_address: {_eq: $address}}) {
    aggregate {
      count
    }
  }
}
    ''';

const String getAuthKeysForPublicKey = r'''
    query getAuthKeysForPublicKey($where_condition: public_key_auth_keys_bool_exp, $order_by: [public_key_auth_keys_order_by!]) {
  public_key_auth_keys(where: $where_condition, order_by: $order_by) {
    public_key
    public_key_type
    auth_key
    account_public_key
    last_transaction_version
    is_public_key_used
    signature_type
  }
}
    ''';

const String getChainTopUserTransactions = r'''
    query getChainTopUserTransactions($limit: Int) {
  user_transactions(limit: $limit, order_by: {version: desc}) {
    version
  }
}
    ''';

const String getCollectionData = r'''
    query getCollectionData($where_condition: current_collections_v2_bool_exp!) {
  current_collections_v2(where: $where_condition) {
    uri
    total_minted_v2
    token_standard
    table_handle_v1
    mutable_uri
    mutable_description
    max_supply
    collection_id
    collection_name
    creator_address
    current_supply
    description
    last_transaction_timestamp
    last_transaction_version
  }
}
    ''';

const String getCurrentFungibleAssetBalances = r'''
    query getCurrentFungibleAssetBalances($where_condition: current_fungible_asset_balances_bool_exp, $offset: Int, $limit: Int) {
  current_fungible_asset_balances(
    where: $where_condition
    offset: $offset
    limit: $limit
  ) {
    amount
    asset_type
    is_frozen
    is_primary
    last_transaction_timestamp
    last_transaction_version
    owner_address
    storage_id
    token_standard
  }
}
    ''';

const String getDelegatedStakingActivities = r'''
    query getDelegatedStakingActivities($delegatorAddress: String, $poolAddress: String) {
  delegated_staking_activities(
    where: {delegator_address: {_eq: $delegatorAddress}, pool_address: {_eq: $poolAddress}}
  ) {
    amount
    delegator_address
    event_index
    event_type
    pool_address
    transaction_version
  }
}
    ''';

const String getEvents = r'''
    query getEvents($where_condition: events_bool_exp, $offset: Int, $limit: Int, $order_by: [events_order_by!]) {
  events(
    where: $where_condition
    offset: $offset
    limit: $limit
    order_by: $order_by
  ) {
    account_address
    creation_number
    data
    event_index
    sequence_number
    transaction_block_height
    transaction_version
    type
    indexed_type
  }
}
    ''';

const String getFungibleAssetActivities = r'''
    query getFungibleAssetActivities($where_condition: fungible_asset_activities_bool_exp, $offset: Int, $limit: Int) {
  fungible_asset_activities(
    where: $where_condition
    offset: $offset
    limit: $limit
  ) {
    amount
    asset_type
    block_height
    entry_function_id_str
    event_index
    gas_fee_payer_address
    is_frozen
    is_gas_fee
    is_transaction_success
    owner_address
    storage_id
    storage_refund_amount
    token_standard
    transaction_timestamp
    transaction_version
    type
  }
}
    ''';

const String getFungibleAssetMetadata = r'''
    query getFungibleAssetMetadata($where_condition: fungible_asset_metadata_bool_exp, $offset: Int, $limit: Int) {
  fungible_asset_metadata(where: $where_condition, offset: $offset, limit: $limit) {
    icon_uri
    project_uri
    supply_aggregator_table_handle_v1
    supply_aggregator_table_key_v1
    creator_address
    asset_type
    decimals
    last_transaction_timestamp
    last_transaction_version
    name
    symbol
    token_standard
    supply_v2
    maximum_v2
  }
}
    ''';

const String getNames = r'''
    query getNames($offset: Int, $limit: Int, $where_condition: current_aptos_names_bool_exp, $order_by: [current_aptos_names_order_by!]) {
  current_aptos_names(
    limit: $limit
    where: $where_condition
    order_by: $order_by
    offset: $offset
  ) {
    ...AnsTokenFragment
  }
  current_aptos_names_aggregate(where: $where_condition) {
    aggregate {
      count
    }
  }
}
    ''' +
    ansTokenFragment;

const String getNumberOfDelegators = r'''
    query getNumberOfDelegators($where_condition: num_active_delegator_per_pool_bool_exp, $order_by: [num_active_delegator_per_pool_order_by!]) {
  num_active_delegator_per_pool(where: $where_condition, order_by: $order_by) {
    num_active_delegator
    pool_address
  }
}
    ''';

const String getObjectData = r'''
    query getObjectData($where_condition: current_objects_bool_exp, $offset: Int, $limit: Int, $order_by: [current_objects_order_by!]) {
  current_objects(
    where: $where_condition
    offset: $offset
    limit: $limit
    order_by: $order_by
  ) {
    allow_ungated_transfer
    state_key_hash
    owner_address
    object_address
    last_transaction_version
    last_guid_creation_num
    is_deleted
  }
}
    ''';

const String getProcessorStatus = r'''
    query getProcessorStatus($where_condition: processor_status_bool_exp) {
  processor_status(where: $where_condition) {
    last_success_version
    processor
    last_updated
  }
}
    ''';

const String getTableItemsData = r'''
    query getTableItemsData($where_condition: table_items_bool_exp!, $offset: Int, $limit: Int, $order_by: [table_items_order_by!]) {
  table_items(
    where: $where_condition
    offset: $offset
    limit: $limit
    order_by: $order_by
  ) {
    decoded_key
    decoded_value
    key
    table_handle
    transaction_version
    write_set_change_index
  }
}
    ''';

const String getTableItemsMetadata = r'''
    query getTableItemsMetadata($where_condition: table_metadatas_bool_exp!, $offset: Int, $limit: Int, $order_by: [table_metadatas_order_by!]) {
  table_metadatas(
    where: $where_condition
    offset: $offset
    limit: $limit
    order_by: $order_by
  ) {
    handle
    key_type
    value_type
  }
}
    ''';

const String getTokenActivity = r'''
    query getTokenActivity($where_condition: token_activities_v2_bool_exp!, $offset: Int, $limit: Int, $order_by: [token_activities_v2_order_by!]) {
  token_activities_v2(
    where: $where_condition
    order_by: $order_by
    offset: $offset
    limit: $limit
  ) {
    ...TokenActivitiesFields
  }
}
    ''' +
    tokenActivitiesFieldsFragment;

const String getCurrentTokenOwnership = r'''
    query getCurrentTokenOwnership($where_condition: current_token_ownerships_v2_bool_exp!, $offset: Int, $limit: Int, $order_by: [current_token_ownerships_v2_order_by!]) {
  current_token_ownerships_v2(
    where: $where_condition
    offset: $offset
    limit: $limit
    order_by: $order_by
  ) {
    ...CurrentTokenOwnershipFields
  }
}
    ''' +
    currentTokenOwnershipFieldsFragment;

const String getTokenData = r'''
    query getTokenData($where_condition: current_token_datas_v2_bool_exp, $offset: Int, $limit: Int, $order_by: [current_token_datas_v2_order_by!]) {
  current_token_datas_v2(
    where: $where_condition
    offset: $offset
    limit: $limit
    order_by: $order_by
  ) {
    collection_id
    description
    is_fungible_v2
    largest_property_version_v1
    last_transaction_timestamp
    last_transaction_version
    maximum
    supply
    token_data_id
    token_name
    token_properties
    token_standard
    token_uri
    decimals
    current_collection {
      collection_id
      collection_name
      creator_address
      current_supply
      description
      last_transaction_timestamp
      last_transaction_version
      max_supply
      mutable_description
      mutable_uri
      table_handle_v1
      token_standard
      total_minted_v2
      uri
    }
  }
}
    ''';
