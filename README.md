# 🎓 Scholar - On-Chain Scholarship Disbursement System

A Clarity smart contract that automatically distributes scholarship funds to students once they meet pre-defined academic requirements on the Stacks blockchain.

## 🌟 Features

- **🏫 Student Registration**: Students can register with their academic information
- **💰 Scholarship Creation**: Administrators can create scholarships with specific requirements
- **📊 Academic Tracking**: Real-time GPA and credit hour monitoring
- **🔄 Automatic Disbursement**: Funds are automatically released when requirements are met
- **🔐 Multi-Admin Support**: Multiple administrators can manage scholarships
- **✅ Student Verification**: Built-in verification system for academic credentials

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository
2. Navigate to the project directory
3. Run `clarinet check` to verify the contract

## 📋 Contract Functions

### 🎯 Core Functions

#### Student Management
- `register-student(name, institution)` - Register a new student
- `update-academic-record(student-id, gpa, credit-hours)` - Update academic performance
- `verify-student(student-id)` - Verify a student (admin only)

#### Scholarship Management
- `create-scholarship(name, amount, gpa-requirement, credit-hours-requirement, deadline-block)` - Create a new scholarship
- `apply-for-scholarship(student-id, scholarship-id)` - Apply for a scholarship
- `check-and-disburse(student-id, scholarship-id)` - Check requirements and disburse funds
- `deactivate-scholarship(scholarship-id)` - Deactivate a scholarship

#### Funding
- `fund-contract()` - Add funds to the contract
- `withdraw-funds(amount)` - Withdraw funds (owner only)

### 📖 Read-Only Functions

- `get-scholarship(scholarship-id)` - Get scholarship details
- `get-student(student-id)` - Get student information
- `get-student-by-wallet(wallet)` - Find student by wallet address
- `get-application(student-id, scholarship-id)` - Get application status
- `check-eligibility(student-id, scholarship-id)` - Check if student meets requirements
- `get-contract-balance()` - Get available contract funds

## 🎮 Usage Examples

### Creating a Scholarship

```clarity
(contract-call? .Scholar create-scholarship 
  "Excellence Award" 
  u1000000000 
  u350 
  u60 
  u144000)
```

### Registering as a Student

```clarity
(contract-call? .Scholar register-student 
  "Alice Johnson" 
  "State University")
```

### Applying for Scholarship

```clarity
(contract-call? .Scholar apply-for-scholarship u1 u1)
```

### Checking Eligibility

```clarity
(contract-call? .Scholar check-eligibility u1 u1)
```

## 🔧 Configuration

### Academic Requirements

- **GPA**: Stored as integer (350 = 3.50 GPA)
- **Credit Hours**: Minimum completed credit hours required
- **Deadline**: Block height deadline for applications

### Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only operation |
| u101 | Record not found |
| u102 | Already exists |
| u103 | Insufficient funds |
| u104 | Requirements not met |
| u105 | Already disbursed |
| u106 | Inactive scholarship |
| u107 | Invalid amount |
| u108 | Unauthorized operation |

## 🏗️ Architecture

### Data Structures

1. **Scholarships**: Store scholarship details and requirements
2. **Students**: Track student information and academic records
3. **Student-Scholarships**: Link students to scholarship applications
4. **Admins**: Manage scholarship administration rights

### Security Features

- ✅ Owner-only functions for critical operations
- ✅ Student verification system
- ✅ Authorization checks for all operations
- ✅ Funds safety with balance tracking
- ✅ Deadline enforcement for applications

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

Check contract syntax:

```bash
clarinet check
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is open source and available under the MIT License.

## 🔗 Resources

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/write-smart-contracts/clarity-language)
- [Clarinet Documentation](https://github.com/hirosystems/clarinet)

---

Built with ❤️ for educational empowerment on the Stacks blockchain 🚀
