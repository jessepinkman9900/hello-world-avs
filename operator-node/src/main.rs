use std::str::FromStr;

use alloy::providers::Provider;
use alloy::{
    eips::BlockNumberOrTag,
    primitives::Address,
    providers::{ProviderBuilder, WsConnect},
    rpc::types::Filter,
    sol,
    sol_types::SolEvent,
};
use eyre::Result;
use futures_util::stream::StreamExt;
use log;
use serde::Deserialize;

sol!(
    #[allow(missing_docs)]
    #[sol(rpc)]
    SquaringTaskManager,
    "../contracts/out/SquaringTaskManager.sol/SquaringTaskManager.json"
);

#[derive(Deserialize, Debug)]
struct Config {
    ws_url: String,
    task_manager_address: String,
    operator_private_key: String,
}

fn load_config() -> Result<Config> {
    match envy::from_env::<Config>() {
        Ok(config) => {
            log::info!("Loaded config: {config:?}");
            Ok(config)
        }
        Err(e) => {
            log::error!("Failed to load config: {e}");
            Err(e.into())
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::init();
    log::info!("Starting operator node");
    // load env variables
    let config = load_config()?;

    // create provider
    let rpc_url = &config.ws_url;
    let ws = WsConnect::new(rpc_url);
    let provider = ProviderBuilder::new().on_ws(ws).await?;
    log::info!("Provider created");
    let block_number = provider.get_block_number().await?;
    log::info!("Block number: {block_number}");

    // create filter
    let task_manager_address = Address::from_str(&config.task_manager_address).unwrap();
    log::info!("Task manager address: {}", task_manager_address.clone());
    let filter = Filter::new()
        .address(task_manager_address)
        .event("NewTaskCreated(uint32,(uint256,uint32,bytes,uint32))")
        .from_block(BlockNumberOrTag::Earliest);

    // subscribe to logs
    let subscription = provider.subscribe_logs(&filter).await?;
    let mut stream = subscription.into_stream();
    log::info!("Subscribed to logs");

    // handle events
    while let Some(log) = stream.next().await {
        match log.topic0() {
            Some(&SquaringTaskManager::NewTaskCreated::SIGNATURE_HASH) => {
                let SquaringTaskManager::NewTaskCreated { taskIndex, task } =
                    log.log_decode()?.inner.data;
                log::info!("New task created: {taskIndex:?}");
                log::info!(
                    "NewTaskCreated numberToBeSquared::{} quorumNumbers::{} quorumThresholdPercentage::{} taskCreatedBlockNumber::{}",
                    task.numberToBeSquared,
                    task.quorumNumbers,
                    task.quorumThresholdPercentage,
                    task.taskCreatedBlockNumber
                );
                squaring_task_handler::handle_task(&provider, &config, taskIndex, task).await?;
            }
            _ => {}
        }
    }

    Ok(())
}

mod squaring_task_handler {
    use alloy::primitives::Uint;
    use alloy::{providers::Provider, rpc::types::TransactionRequest};

    use crate::{Config, ISquaringTaskManager::Task};

    pub async fn handle_task(
        provider: impl Provider,
        config: &Config,
        task_index: u32,
        task: Task,
    ) -> Result<(), eyre::Error> {
        // get latest block
        let latest_block = provider.get_block_number().await?;
        log::info!("Latest block: {latest_block}");

        // log config
        log::info!("Config private key: {}", config.operator_private_key);

        // task
        let result = task.numberToBeSquared.pow(Uint::from(2));
        log::info!("Result: {result}");

        // send result
        // todo
        // let tx = TransactionRequest::default().

        Ok(())
    }
}
