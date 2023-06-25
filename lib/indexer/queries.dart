const CurrentTokenOwnershipFieldsFragmentDoc = '''
    fragment CurrentTokenOwnershipFields on current_token_ownerships_v2 {
  token_standard
  is_fungible_v2
  is_soulbound_v2
  property_version_v1
  table_type_v1
  token_properties_mutated_v1
  amount
  last_transaction_timestamp
  last_transaction_version
  storage_id
  owner_address
  current_token_data {
    token_name
    token_data_id
    token_uri
    token_properties
    supply
    maximum
    last_transaction_version
    last_transaction_timestamp
    largest_property_version_v1
    current_collection {
      collection_name
      creator_address
      description
      uri
      collection_id
      last_transaction_version
      current_supply
      mutable_description
      total_minted_v2
      table_handle_v1
      mutable_uri
    }
  }
}
    ''';

const TokenDataFieldsFragmentDoc = '''
    fragment TokenDataFields on current_token_datas {
  creator_address
  collection_name
  description
  metadata_uri
  name
  token_data_id_hash
  collection_data_id_hash
}
    ''';
    
const CollectionDataFieldsFragmentDoc = '''
    fragment CollectionDataFields on current_collection_datas {
  metadata_uri
  supply
  description
  collection_name
  collection_data_id_hash
  table_handle
  creator_address
}
    ''';
const GetAccountCoinsData = r'''
    query getAccountCoinsData($owner_address: String, $offset: Int, $limit: Int) {
  current_coin_balances(
    where: {owner_address: {_eq: $owner_address}}
    offset: $offset
    limit: $limit
  ) {
    amount
    coin_type
    coin_info {
      name
      decimals
      symbol
    }
  }
}
    ''';
const GetAccountCurrentTokens = r'''
    query getAccountCurrentTokens($address: String!, $offset: Int, $limit: Int) {
  current_token_ownerships(
    where: {owner_address: {_eq: $address}, amount: {_gt: 0}}
    order_by: [{last_transaction_version: desc}, {creator_address: asc}, {collection_name: asc}, {name: asc}]
    offset: $offset
    limit: $limit
  ) {
    amount
    current_token_data {
      ...TokenDataFields
    }
    current_collection_data {
      ...CollectionDataFields
    }
    last_transaction_version
    property_version
  }
}''' + TokenDataFieldsFragmentDoc 
+ CollectionDataFieldsFragmentDoc;

const GetAccountTokensCount = r'''
    query getAccountTokensCount($owner_address: String) {
  current_token_ownerships_aggregate(
    where: {owner_address: {_eq: $owner_address}, amount: {_gt: "0"}}
  ) {
    aggregate {
      count
    }
  }
}
    ''';

const GetAccountTransactionsCount = r'''
    query getAccountTransactionsCount($address: String) {
  move_resources_aggregate(
    where: {address: {_eq: $address}}
    distinct_on: transaction_version
  ) {
    aggregate {
      count
    }
  }
}
    ''';

const GetAccountTransactionsData = r'''
    query getAccountTransactionsData($address: String, $limit: Int, $offset: Int) {
  move_resources(
    where: {address: {_eq: $address}}
    order_by: {transaction_version: desc}
    distinct_on: transaction_version
    limit: $limit
    offset: $offset
  ) {
    transaction_version
  }
}
    ''';

const GetCurrentDelegatorBalancesCount = r'''
    query getCurrentDelegatorBalancesCount($poolAddress: String) {
  current_delegator_balances_aggregate(
    where: {pool_type: {_eq: "active_shares"}, pool_address: {_eq: $poolAddress}, amount: {_gt: "0"}}
    distinct_on: delegator_address
  ) {
    aggregate {
      count
    }
  }
}
    ''';

const GetCollectionData = r'''
    query getCollectionData($where_condition: current_collections_v2_bool_exp!, $offset: Int, $limit: Int) {
  current_collections_v2(where: $where_condition, offset: $offset, limit: $limit) {
    collection_id
    token_standard
    collection_name
    creator_address
    current_supply
    description
    uri
  }
}
    ''';

const GetCollectionsWithOwnedTokens = r'''
    query getCollectionsWithOwnedTokens($where_condition: current_collection_ownership_v2_view_bool_exp!, $offset: Int, $limit: Int) {
  current_collection_ownership_v2_view(
    where: $where_condition
    order_by: {last_transaction_version: desc}
    offset: $offset
    limit: $limit
  ) {
    current_collection {
      creator_address
      collection_name
      token_standard
      collection_id
      description
      table_handle_v1
      uri
      total_minted_v2
      max_supply
    }
    distinct_tokens
    last_transaction_version
  }
}
    ''';

const GetDelegatedStakingActivities = r'''
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

const GetIndexerLedgerInfo = r'''
    query getIndexerLedgerInfo {
  ledger_infos {
    chain_id
  }
}
    ''';

const GetTokenActivities = r'''
    query getTokenActivities($idHash: String!, $offset: Int, $limit: Int) {
  token_activities(
    where: {token_data_id_hash: {_eq: $idHash}}
    order_by: {transaction_version: desc}
    offset: $offset
    limit: $limit
  ) {
    creator_address
    collection_name
    name
    token_data_id_hash
    collection_data_id_hash
    from_address
    to_address
    transaction_version
    transaction_timestamp
    property_version
    transfer_type
    event_sequence_number
    token_amount
  }
}
    ''';
const GetTokenActivitiesCount = r'''
    query getTokenActivitiesCount($token_id: String) {
  token_activities_aggregate(where: {token_data_id_hash: {_eq: $token_id}}) {
    aggregate {
      count
    }
  }
}
    ''';

const GetTokenOwnedFromCollection = r'''
    query getTokenOwnedFromCollection($where_condition: current_token_ownerships_v2_bool_exp!, $offset: Int, $limit: Int) {
  current_token_ownerships_v2(
    where: $where_condition
    offset: $offset
    limit: $limit
  ) {
    ...CurrentTokenOwnershipFields
  }
}''' + CurrentTokenOwnershipFieldsFragmentDoc;

const GetTokenData = r'''
    query getTokenData($token_id: String) {
  current_token_datas(where: {token_data_id_hash: {_eq: $token_id}}) {
    token_data_id_hash
    name
    collection_name
    creator_address
    default_properties
    largest_property_version
    maximum
    metadata_uri
    payee_address
    royalty_points_denominator
    royalty_points_numerator
    supply
  }
}
    ''';

const GetTokenOwnersData = r'''
    query getTokenOwnersData($token_id: String, $property_version: numeric) {
  current_token_ownerships(
    where: {token_data_id_hash: {_eq: $token_id}, property_version: {_eq: $property_version}}
  ) {
    owner_address
  }
}
    ''';

const GetTopUserTransactions = r'''
    query getTopUserTransactions($limit: Int) {
  user_transactions(limit: $limit, order_by: {version: desc}) {
    version
  }
}
    ''';

const GetUserTransactions = r'''
    query getUserTransactions($limit: Int, $start_version: bigint, $offset: Int) {
  user_transactions(
    limit: $limit
    order_by: {version: desc}
    where: {version: {_lte: $start_version}}
    offset: $offset
  ) {
    version
  }
}
    ''';

const GetAccountCoinActivity = r'''
  query getAccountCoinActivity($address: String!, $offset: Int, $limit: Int) {
    coin_activities(
      where: {owner_address: {_eq: $address}}
      limit: $limit
      offset: $offset
      order_by: [{transaction_version: desc}, {event_account_address: desc}, {event_creation_number: desc}, {event_sequence_number: desc}]
    ) {
      ...CoinActivityFields
    }
  }

  fragment CoinActivityFields on coin_activities {
    transaction_timestamp
    transaction_version
    amount
    activity_type
    coin_type
    is_gas_fee
    is_transaction_success
    event_account_address
    event_creation_number
    event_sequence_number
    entry_function_id_str
    block_height
  }
''';

const GetAccountSpecifiedCoinActivity = r'''
  query getAccountSpecifiedCoinActivity($coin: String!, $address: String!, $offset: Int, $limit: Int) {
    coin_activities(
      where: {coin_type: {_eq: $coin}, owner_address: {_eq: $address}}
      limit: $limit
      offset: $offset
      order_by: [{transaction_version: desc}, {event_account_address: desc}, {event_creation_number: desc}, {event_sequence_number: desc}]
    ) {
      ...CoinActivityFields
    }
  }

  fragment CoinActivityFields on coin_activities {
    transaction_timestamp
    transaction_version
    amount
    activity_type
    coin_type
    is_gas_fee
    is_transaction_success
    event_account_address
    event_creation_number
    event_sequence_number
    entry_function_id_str
    block_height
  }
''';

const GetCoinInfo = r'''
  query getCoinInfo($coin: String!) {
    coin_infos(
      where: {coin_type: {_eq: $coin}}
    ) {
      ...CoinInfoFields
    }
  }

  fragment CoinInfoFields on coin_infos {
    name
    decimals
    symbol
  }
''';