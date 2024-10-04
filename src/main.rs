use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::env;
use std::time::Duration;
use tokio::time::sleep;
use dotenv::dotenv;

#[derive(Serialize)]
struct DnsRecord {
    #[serde(rename = "type")]
    record_type: String,
    name: String,
    content: String,
    ttl: u32,
    proxied: bool,
}

#[derive(Deserialize)]
struct DnsRecordResponse {
    result: DnsRecordResult,
}

#[derive(Deserialize)]
struct DnsRecordResult {
    content: String,
}

async fn get_public_ip() -> Result<String, Box<dyn std::error::Error>> {
    let response = reqwest::get("http://checkip.amazonaws.com").await?;
    let public_ip = response.text().await?.trim().to_string();
    Ok(public_ip)
}

async fn get_current_dns_record(url: &str, auth_email: &str, auth_key: &str) -> Result<String, Box<dyn std::error::Error>> {
    let client = Client::new();

    let response = client
        .get(url)
        .header("Content-Type", "application/json")
        .header("X-Auth-Email", auth_email)
        .header("X-Auth-Key", auth_key)
        .send()
        .await?;

    let response_text = response.text().await?;
    
    // Print the raw response for debugging purposes
    println!("Raw response from server: {}", response_text);

    // Try to deserialize the response and handle any errors
    let dns_record_response: Result<DnsRecordResponse, _> = serde_json::from_str(&response_text);
    
    match dns_record_response {
        Ok(dns_response) => Ok(dns_response.result.content),
        Err(e) => {
            eprintln!("Failed to parse DNS record response: {}. Raw response was: {}", e, response_text);
            Err(Box::new(e))
        }
    }
}

async fn update_dns_record(public_ip: &str, url: &str, auth_email: &str, auth_key: &str, dns_name: &str) -> Result<(), Box<dyn std::error::Error>> {
    let client = Client::new();

    // Check for the CLOUDFLARE_PROXIED env variable, defaulting to true if not set
    let proxied = env::var("CLOUDFLARE_PROXIED")
        .map_or(true, |val| val.to_lowercase() != "false");

    let dns_record = DnsRecord {
        record_type: "A".to_string(),
        name: dns_name.to_string(),
        content: public_ip.to_string(),
        ttl: 120,
        proxied,
    };

    let response = client
        .put(url)
        .header("Content-Type", "application/json")
        .header("X-Auth-Email", auth_email)
        .header("X-Auth-Key", auth_key)
        .json(&dns_record)
        .send()
        .await?;

    let response_text = response.text().await?;
    println!("Response from Cloudflare: {}", response_text);

    Ok(())
}

#[tokio::main]
async fn main() {
    dotenv().ok();

    let url = env::var("CLOUDFLARE_API_URL").expect("CLOUDFLARE_API_URL not set");
    let auth_email = env::var("CLOUDFLARE_AUTH_EMAIL").expect("CLOUDFLARE_AUTH_EMAIL not set");
    let auth_key = env::var("CLOUDFLARE_AUTH_KEY").expect("CLOUDFLARE_AUTH_KEY not set");
    let dns_name = env::var("CLOUDFLARE_DNS_NAME").expect("CLOUDFLARE_DNS_NAME not set");
    let sleep_duration = env::var("SLEEP_DURATION")
        .unwrap_or_else(|_| "3600".to_string())
        .parse::<u64>()
        .expect("SLEEP_DURATION must be a number");

    loop {
        match get_public_ip().await {
            Ok(public_ip) => {
                println!("Detected public IP: {}", public_ip);

                match get_current_dns_record(&url, &auth_email, &auth_key).await {
                    Ok(current_ip) => {
                        if current_ip != public_ip {
                            println!("IP address has changed from {} to {}. Updating DNS record.", current_ip, public_ip);
                            if let Err(e) = update_dns_record(&public_ip, &url, &auth_email, &auth_key, &dns_name).await {
                                eprintln!("Failed to update DNS record: {}", e);
                            }
                        } else {
                            println!("IP address has not changed. No update needed.");
                        }
                    }
                    Err(e) => eprintln!("Failed to get current DNS record: {}", e),
                }
            }
            Err(e) => eprintln!("Failed to get public IP: {}", e),
        }

        println!("Sleeping for {} seconds...", sleep_duration);
        sleep(Duration::from_secs(sleep_duration)).await;
    }
}

