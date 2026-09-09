# 🌐 Complete AWS Networking Guide: Architecture, Flow & Scenarios

This document explains **AWS Networking fundamentals**, packet process flows, and real-world scenarios designed specifically for your Kubernetes infrastructure.

---

## 📌 1. Fundamental Networking Components

| Component | AWS Resource | What it does | Real-World Analogy |
| :--- | :--- | :--- | :--- |
| **VPC** | `aws_vpc` | Your isolated virtual private network in AWS (e.g. `10.10.0.0/16` = 65,536 IPs). | Private Gated Land / Property |
| **Subnet** | `aws_subnet` | A subdivided block of IPs inside a VPC (e.g. `10.10.1.0/24` = 256 IPs). | A specific Room inside your house |
| **Internet Gateway** | `aws_internet_gateway` | VPC border component enabling communication between your VPC and the Internet. | The Front Gate of your property |
| **Route Table** | `aws_route_table` | A set of rules (routes) determining where network traffic is directed. | Hallway Directional Signs |
| **Security Group** | `aws_security_group` | Stateful virtual firewall controlling Inbound & Outbound traffic for EC2. | Security Guard at the room door |
| **Public IP** | `map_public_ip_on_launch` | Globally routable IP address accessible over the Internet. | Public Phone Number / Street Address |
| **Private IP** | Auto-assigned | Internal IP accessible ONLY within the VPC (e.g. `10.10.1.15`). | Internal Room Number / Extension |

---

## 🚀 2. Real-World Scenarios & Packet Process Flows

---

### 🟢 Scenario 1: Inbound SSH Connection (Laptop ➔ K8s Master EC2)
**Goal**: You run `ssh ubuntu@54.210.15.20` from your local computer terminal to log into the K8s Master node.

```mermaid
sequenceDiagram
    autonumber
    actor User as 💻 Your Laptop
    participant IGW as 🚪 Internet Gateway
    participant RT as 🛣️ Route Table
    participant SG as 🛡️ Master Security Group
    participant EC2 as 🖥️ K8s Master EC2 (10.10.1.10)

    User->>IGW: 1. SSH TCP Request (Port 22) -> Destination: 54.210.15.20
    IGW->>RT: 2. Translates Public IP (54.210.15.20) to Private IP (10.10.1.10)
    RT->>SG: 3. Forwards packet to Public Subnet ENI
    Note over SG: SG Rule Check:<br/>Is Port 22 allowed from 0.0.0.0/0?<br/>✅ YES (Rule Matches!)
    SG->>EC2: 4. Packet passes through firewall to Linux OS
    EC2-->>User: 5. SSH Response returned & Session Established 🎉
```

#### Step-by-Step Explanation:
1. **Initiation**: Your laptop sends a TCP packet on port `22` to the public IP `54.210.15.20`.
2. **IGW Translation**: The Internet Gateway receives the packet at the VPC border and translates the Public IP `54.210.15.20` to the internal Private IP `10.10.1.10`.
3. **Subnet Routing**: The Subnet's Route Table recognizes `10.10.1.10` belongs to `k8s-public-subnet`.
4. **Security Group Check**: Before touching the EC2 network interface (ENI), **Security Group (`k8s-master-sg`)** checks its ingress rules:
   - *Rule*: Ingress TCP Port 22 from `0.0.0.0/0` -> **ALLOWED**.
5. **OS Handshake**: The packet hits port 22 of the Linux OS where OpenSSH daemon receives it and completes authentication.

---

### 🔵 Scenario 2: Outbound Internet Access (K8s Master EC2 ➔ Internet)
**Goal**: The Master EC2 node runs `apt-get update` or downloads Kubernetes packages from `https://packages.cloud.google.com`.

```mermaid
sequenceDiagram
    autonumber
    participant EC2 as 🖥️ K8s Master EC2 (10.10.1.10)
    participant SG as 🛡️ Master Security Group
    participant RT as 🛣️ Route Table
    participant IGW as 🚪 Internet Gateway
    actor Server as 🌐 Ubuntu Repository Server

    EC2->>SG: 1. Sends Outbound HTTPS Request (Port 443) -> Target: 0.0.0.0/0
    Note over SG: SG Rule Check:<br/>Is Outbound (Egress) allowed?<br/>✅ YES (Port 0-65535 to 0.0.0.0/0)
    SG->>RT: 2. Forwards packet to Subnet Route Table
    Note over RT: Route Check:<br/>Target 0.0.0.0/0 matches route:<br/>via igw-xxxxxx
    RT->>IGW: 3. Routes packet to Internet Gateway
    IGW->>Server: 4. NAT converts 10.10.1.10 -> 54.210.15.20 & sends over Internet
    Server-->>EC2: 5. Response returned back seamlessly
```

#### Step-by-Step Explanation:
1. **Application Request**: Kubelet or APT on the EC2 instance creates a packet targeting external IP `185.125.190.36:80`.
2. **Security Group Egress Check**: Security Group checks egress rules:
   - *Rule*: Egress All Traffic (`-1`) to `0.0.0.0/0` -> **ALLOWED**.
3. **Route Table Lookup**: Subnet Route Table checks destination:
   - `0.0.0.0/0` -> `gateway_id = aws_internet_gateway.k8s_igw.id`.
4. **IGW Network Address Translation (NAT)**: The IGW substitutes the source Private IP (`10.10.1.10`) with the EC2's Public IP (`54.210.15.20`).
5. **Return Traffic**: Because Security Groups are **stateful**, return traffic is automatically allowed back through without needing an explicit inbound rule!

---

### 🟣 Scenario 3: Internal Cluster Communication (Master Node ➔ Worker Node)
**Goal**: K8s Master Node (`10.10.1.10`) connects to K8s Worker Node (`10.10.1.20`) on Kubelet Port `10250` or Flannel CNI overlay UDP `8472`.

```mermaid
sequenceDiagram
    autonumber
    participant Master as 👑 K8s Master (10.10.1.10)
    participant VPC_Router as 🔀 VPC Internal Router (10.10.0.0/16)
    participant Worker_SG as 🛡️ Worker Security Group
    participant Worker as 👷 K8s Worker (10.10.1.20)

    Master->>VPC_Router: 1. Request to 10.10.1.20:10250 (Kubelet Logs/Exec)
    Note over VPC_Router: Target 10.10.1.20 matches local CIDR (10.10.0.0/16)<br/>❌ Does NOT go to Internet Gateway!
    VPC_Router->>Worker_SG: 2. Direct internal routing inside AWS backbone
    Note over Worker_SG: Ingress Check on Worker SG:<br/>- Port 10250 allowed? ✅ YES<br/>- Self/Internal traffic allowed? ✅ YES
    Worker_SG->>Worker: 3. Delivered directly to Worker Kubelet process
    Worker-->>Master: 4. Internal response sent back to Master
```

#### Step-by-Step Explanation:
1. **Targeting Private IP**: The Master node sends traffic directly to `10.10.1.20` (Worker Private IP).
2. **Local VPC Route**: Every AWS VPC has an automatic default route:
   - `10.10.0.0/16` -> `local`.
   - Traffic **never leaves the AWS network** and **never touches the Internet Gateway**.
3. **Worker Security Group Check**:
   - `worker_sg` checks if port `10250` or internal self-traffic (`protocol = -1`, `self = true`) is allowed -> **ALLOWED**.
4. **Zero Latency High Speed**: Data is transferred over AWS high-speed private fiber infrastructure (up to 10Gbps+).

---

## 🇰🇭 3. សង្ខេបជាភាសាខ្មែរ (Khmer Summary Note)

1. **VPC (`10.10.0.0/16`)**: គឺជា **បណ្តាញផ្ទៃក្នុង (Private Network)** ទាំងមូលនៅក្នុង AWS។
2. **Subnet (`10.10.1.0/24`)**: គឺជា **ផ្នែកមួយនៃ Network** ដែល EC2 របស់អ្នករស់នៅ។
3. **Internet Gateway (IGW)**: គឺជា **ទ្វារចេញចូល Internet**។ បើគ្មាន IGW ទេ EC2 មិនអាចដោនឡូត Docker ឬ K8s ពីក្រៅបានឡើយ។
4. **Route Table**: គឺជា **អ្នកចង្អុលផ្លូវ**។ វាប្រាប់ Subnet ថា បើចង់ចេញទៅពិភពខាងក្រៅ (`0.0.0.0/0`) ត្រូវដើរទៅកាន់ **IGW**។
5. **Security Group**: គឺជា **របាំងការពារ (Firewall)** នៅពីមុខ EC2។ វាពិនិត្យ Port នីមួយៗ (ដូចជា Port 22 SSH, 6443 K8s API, 10250 Kubelet)។ បើគ្មានអនុញ្ញាតក្នុង SG ទេ Packet នឹងត្រូវ Reject ភ្លាមៗ។
