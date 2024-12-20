# AWS Projects

# Project Documentation

## Project Structure
     ______________
    /_AWS-Project_./                                       
       │ │        ├── launcher.sh  
     __│ │____                                           
    /__env__./                                               
       │ │  ├── variables.env                                              
       │ │  ├── launcher.env                                                     
      _│ │_________________________________________________________________________________________
     /_core_./           /_phase_files_./             /_data_./                     /_asg_config_./
            ├── root.sh                ├── phase1.sh         ├── ec2_v1_userdata.sh              ├── config.json 
            ├── settings.sh            ├── phase2.sh         ├── ec2_v2_userdata.sh
            ├── phase_worker.sh        ├── phase3.sh         ├── sample_entries
            ├── config.sh              ├── phase4.sh 
            ├── map_build.sh           ├── phase5.sh 
            ├── caller.sh  
            ├── constants.sh 

## Overview
This project provides an automated system for provisioning and managing an AWS-based infrastructure for a web application. It includes scripts to configure Virtual Private Clouds (VPCs), subnets, EC2 instances, RDS databases, autoscaling, load balancing, and cleanup of resources.

---

## Key Features
1. **Infrastructure Automation**: Provisioning AWS resources such as EC2 instances, RDS databases, subnets, security groups, load balancers, and autoscaling groups.
2. **Database Management**: Migration of database content from local storage to an RDS instance.
3. **Scalability**: Autoscaling configuration to handle varying loads.
4. **Logging and Error Handling**: Extensive logs are maintained for execution and error tracking.
5. **Cleanup Utility**: Scripts to delete and clean up resources.

---

## Usage Instructions

### 1. Setup

#### Prerequisites
- AWS CLI configured with sufficient permissions.
- Lab session must be reset to prevent conflicts
- Default VPC available in the target AWS region.

#### Environment Variables
Ensure the following files are correctly configured with required variables:
- `variables.env` for user and DB credentials.
- `constants.env` for predefined AWS resource configurations.

---

### 2. Phases of Execution
                                      
     launcher.sh  
     __│ │____                                           
    /root.sh/                                               
       │ │  ├── variables.env                                              
       │ │  ├── launcher.env                                                     
      _│ │_________________________________________________________________________________________
     /_core_./           /_phase_files_./             /_data_./                     /_asg_config_./
            ├──                 ├── phase1.sh         ├── ec2_v1_userdata.sh              ├── config.json 
            ├── settings.sh            ├── phase2.sh         ├── ec2_v2_userdata.sh
            ├── phase_worker.sh        ├── phase3.sh         ├── sample_entries
            ├── config.sh              ├── phase4.sh 
            ├── map_build.sh           ├── phase5.sh 
            ├── caller.sh  
            ├── constants.sh 

The system operates in five phases:

#### Phase 1: Setup VPC, Subnets, and EC2-v1
- Creates a custom VPC with subnets (public, private, and database).
- Sets up security groups and an Internet Gateway.
- Launches EC2-v1 instance with a default in-memory database.

**Execution**:
```sh
source env/phase_files/phase1.sh
```
#### Phase 2: Database Migration to RDS, EC2 Image Creation, and v2 Launch
Migrates the database from EC2-v1 to an RDS instance.
Creates an image of EC2-v1 and launches EC2-v2.
Configures EC2-v2 to communicate with the RDS instance.
**Execution:**
```sh

```
#### Phase 3: Auto Scaling and Load Balancer Setup
Sets up a load balancer and configures an auto-scaling group.
Ensures the application can handle varying loads.
**Execution:**
```sh

```
#### Phase 4: Load Testing
Performs load testing on the auto-scaling group to ensure it can handle high traffic.
**Execution:**
```sh

```
#### Phase 5: Cleanup
Cleans up all provisioned resources to avoid unnecessary costs.
**Execution:**
```sh

```
#### Background Activities
Logs and Debugging
Logs are maintained in the logs directory:
- execution.log: Logs the execution of commands.
- response.log: Logs the responses from AWS CLI commands.
- created_resources.log: Logs the resources created during the execution.

#### Conclusion
This project provides a comprehensive solution for automating the provisioning, management, and cleanup of AWS resources for a web application. By following the phases of execution, users can set up a scalable and robust infrastructure with ease.

