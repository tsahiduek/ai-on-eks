# Hands-On Exercises: Practice AI on EKS

This section provides practical, hands-on exercises and challenges to help you master AI/ML deployments on Amazon EKS. Each exercise builds upon the repository examples and guides you through real-world scenarios.

## Contents

1. [Exercise 1: Deploy Your First LLM](01-deploy-first-llm.md)
   - Deploy a small language model using vLLM
   - Configure autoscaling and monitoring
   - Test inference endpoints
   - **Challenge**: Optimize for cost and performance

2. [Exercise 2: Set Up Distributed Training](02-distributed-training.md)
   - Train a model using Ray on multiple GPUs
   - Configure data loading and checkpointing
   - Monitor training progress
   - **Challenge**: Implement fault tolerance

3. [Exercise 3: Multi-Model Serving Platform](03-multi-model-serving.md)
   - Deploy multiple models with NVIDIA Triton
   - Configure model versioning and A/B testing
   - Implement custom preprocessing
   - **Challenge**: Build a model registry

4. [Exercise 4: Cost Optimization Challenge](04-cost-optimization.md)
   - Analyze current resource usage
   - Implement spot instances for training
   - Right-size inference deployments
   - **Challenge**: Achieve 40% cost reduction

5. [Exercise 5: Production Monitoring Setup](05-production-monitoring.md)
   - Set up comprehensive monitoring stack
   - Create custom dashboards for AI workloads
   - Configure alerting and notifications
   - **Challenge**: Implement predictive scaling

6. [Exercise 6: Security Hardening](06-security-hardening.md)
   - Implement network policies and RBAC
   - Configure secrets management
   - Set up audit logging
   - **Challenge**: Achieve compliance requirements

7. [Exercise 7: Disaster Recovery](07-disaster-recovery.md)
   - Implement backup and restore procedures
   - Test multi-region failover
   - Configure data replication
   - **Challenge**: Achieve RTO < 15 minutes

8. [Exercise 8: Advanced Scaling Scenarios](08-advanced-scaling.md)
   - Implement custom metrics scaling
   - Configure predictive autoscaling
   - Handle traffic spikes and bursts
   - **Challenge**: Scale from 0 to 1000 requests/second

9. [Exercise 9: MLOps Pipeline](09-mlops-pipeline.md)
   - Build end-to-end ML pipeline
   - Implement CI/CD for models
   - Set up automated testing
   - **Challenge**: Deploy with zero downtime

10. [Exercise 10: Troubleshooting Scenarios](10-troubleshooting-scenarios.md)
    - Debug common deployment issues
    - Resolve performance problems
    - Handle resource constraints
    - **Challenge**: Fix production incidents

## How to Use This Section

### Exercise Structure
Each exercise follows this format:
- **Objective**: What you'll accomplish
- **Prerequisites**: What you need before starting
- **Step-by-Step Guide**: Detailed instructions
- **Verification**: How to confirm success
- **Challenge**: Advanced tasks to extend your learning
- **Troubleshooting**: Common issues and solutions

### Difficulty Levels
- 🟢 **Beginner**: Basic deployment and configuration
- 🟡 **Intermediate**: Advanced features and optimization
- 🔴 **Advanced**: Complex scenarios and custom solutions

### Time Estimates
- **Quick Exercises**: 30-60 minutes
- **Standard Exercises**: 1-3 hours
- **Challenge Tasks**: 2-8 hours

## Prerequisites

### Required Knowledge
- Completed the ["What"](../01-what/README.md) and ["Why"](../02-why/README.md) sections
- Basic understanding of Kubernetes concepts
- Familiarity with AI/ML concepts
- Experience with command-line tools

### Required Tools
- AWS CLI configured with appropriate permissions
- kubectl configured for your EKS cluster
- Docker for local testing
- Python 3.8+ for scripting
- Terraform for infrastructure changes

### Required Infrastructure
Most exercises assume you have:
- An EKS cluster set up (see [Cluster Setup Guide](../03-how/01-cluster-setup.md))
- GPU-enabled node groups
- Basic monitoring stack (Prometheus/Grafana)
- Storage classes configured

## Learning Path Recommendations

### Path 1: Infrastructure Focus
For platform engineers and DevOps professionals:
1. Exercise 1: Deploy Your First LLM 🟢
2. Exercise 4: Cost Optimization Challenge 🟡
3. Exercise 5: Production Monitoring Setup 🟡
4. Exercise 6: Security Hardening 🔴
5. Exercise 7: Disaster Recovery 🔴

### Path 2: ML Engineering Focus
For ML engineers and data scientists:
1. Exercise 1: Deploy Your First LLM 🟢
2. Exercise 2: Set Up Distributed Training 🟡
3. Exercise 3: Multi-Model Serving Platform 🟡
4. Exercise 9: MLOps Pipeline 🔴
5. Exercise 10: Troubleshooting Scenarios 🟡

### Path 3: Full-Stack AI Platform
For comprehensive understanding:
1. Complete all exercises in order
2. Focus on challenge tasks
3. Implement custom variations
4. Share solutions with the community

## Assessment and Certification

### Self-Assessment Checklist
After completing exercises, you should be able to:
- [ ] Deploy and scale AI/ML workloads on EKS
- [ ] Optimize costs for training and inference
- [ ] Implement monitoring and observability
- [ ] Secure AI/ML deployments
- [ ] Troubleshoot common issues
- [ ] Design production-ready architectures

### Portfolio Projects
Build these projects to demonstrate your skills:
1. **Multi-Tenant AI Platform**: Support multiple teams and workloads
2. **Cost-Optimized Training Pipeline**: Minimize training costs while maintaining performance
3. **High-Availability Inference Service**: Achieve 99.9% uptime for model serving
4. **Automated MLOps Pipeline**: End-to-end automation from training to deployment

## Community and Support

### Sharing Your Work
- Fork the repository and add your solutions
- Create pull requests with improvements
- Share your experience in GitHub Discussions
- Write blog posts about your learnings

### Getting Help
- **GitHub Issues**: Report problems or ask questions
- **GitHub Discussions**: Community support and discussions
- **AWS Documentation**: Official AWS service documentation
- **Kubernetes Documentation**: Official Kubernetes resources

### Contributing Back
- Submit improvements to existing exercises
- Propose new exercises and challenges
- Share real-world scenarios and solutions
- Help other learners in discussions

## Exercise Completion Tracking

Track your progress through the exercises:

| Exercise | Status | Completion Date | Challenge Completed |
|----------|--------|----------------|-------------------|
| 1. Deploy First LLM | ⬜ | | ⬜ |
| 2. Distributed Training | ⬜ | | ⬜ |
| 3. Multi-Model Serving | ⬜ | | ⬜ |
| 4. Cost Optimization | ⬜ | | ⬜ |
| 5. Production Monitoring | ⬜ | | ⬜ |
| 6. Security Hardening | ⬜ | | ⬜ |
| 7. Disaster Recovery | ⬜ | | ⬜ |
| 8. Advanced Scaling | ⬜ | | ⬜ |
| 9. MLOps Pipeline | ⬜ | | ⬜ |
| 10. Troubleshooting | ⬜ | | ⬜ |

## Next Steps After Completion

Once you've completed these exercises:

1. **Apply to Real Projects**: Use your skills in actual AI/ML projects
2. **Stay Updated**: Follow the repository for new exercises and updates
3. **Contribute**: Help improve the exercises and add new ones
4. **Mentor Others**: Help newcomers learn AI on EKS
5. **Specialize**: Deep dive into specific areas like security, cost optimization, or MLOps

## Repository Integration

These exercises extensively use and build upon:
- **Blueprint Examples**: [/blueprints](../../blueprints) directory
- **Infrastructure Code**: [/infra](../../infra) directory
- **Documentation**: Throughout the repository

Each exercise will guide you through:
- Using existing repository components
- Modifying them for specific scenarios
- Creating new configurations
- Testing and validating your work

Ready to get started? Begin with [Exercise 1: Deploy Your First LLM](01-deploy-first-llm.md)!
