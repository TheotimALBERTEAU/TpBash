# 📂 Log Analysis and Reporting Script (Bash)

This project provides a **Bash script** designed to analyze three specific log files from a web application environment (an Actix web server behind an NGINX reverse proxy). The script performs log filtering, creates blacklists, and determines application uptime/downtime periods.

---

## 🚀 Execution

To execute the script, you must have the three required log files (`actix.log`, `nginx_access.log`, and `nginx_error.log`) located in a subdirectory named `logs` relative to the script's location.

### Prerequisites

* A **Linux/Unix environment** with **Bash** and standard core utilities (`grep`, `awk`, `sort`, `uniq`, `sed`, etc.).

### Usage

1.  Make the script executable:
    ```bash
    chmod +x script_bash.sh
    ```
2.  Run the script, providing the paths to the log files as arguments:

    ```bash
    ./script_bash.sh ./logs/actix.log ./logs/nginx_access.log ./logs/nginx_error.log
    ```

    > **Note:** The script verifies that exactly three arguments are provided. If not, it will display the usage instructions and exit.

---

## 📋 Script Functionality Overview

The `script_bash.sh` performs four main analytical tasks:

### 1. Most Served Resources (`most_served.txt`)

This section analyzes the **Actix log** to identify the most frequently accessed dynamic or large static resources:

* **Filtering:** It isolates successful (**HTTP 200**) **GET** requests.
* **Exclusion:** It explicitly **excludes** requests for common lightweight static assets like `.png`, `.ico`, `.css`, and `.js`.
* **Threshold:** It calculates resource frequency and only reports paths that have been served **more than 10 times**.
* **Output:** The results are saved to `most_served.txt` in the format `[RESOURCE_PATH] : [COUNT]`.

### 2. IP Blacklisting (`ip_blacklist.txt`)

This section compiles a list of suspicious IP addresses from the **NGINX access log**:

* **Sensitive Access:** It blacklists IPs that have attempted to access restricted or sensitive endpoints such as `admin`, `debug`, `login`, or the internal `.git` directory.
* **Non-Standard Methods:** It blacklists IPs whose requests **do not** use standard HTTP methods (`GET`, `POST`, or `HEAD`), often indicating automated scanning or malicious intent.
* **Final List:** The script combines the IPs from both criteria, sorts them, and removes duplicates to produce a clean list in `ip_blacklist.txt`.

### 3. Service Uptime and Downtime Analysis

The script monitors the connection health between NGINX and the Actix upstream server:

* **Downtime Detection (`DOWNTIME`):** It searches the **NGINX error log** for the specific message `"111: Unknown error"`, which signifies a **connection refusal** by the backend (Actix).
* **Uptime Detection (`UPTIME`):** It extracts timestamps from the **Actix log** using `sed` and marks these events as the service being **"UP"**.

### 4. State Change Report (Console Output)

The final output is a timeline of the application's availability:

* The script combines the `DOWN` (NGIN