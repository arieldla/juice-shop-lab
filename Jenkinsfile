pipeline {
  agent any

  environment {
    APP_NAME     = "juice-shop"
    GHCR_REPO    = "ghcr.io/arieldla/juice-shop"
    GITEA_REPO   = "192.168.0.102:3000/arieldla/juice-shop"
    AWS_REGION       = "us-east-1"
    AWS_DEFAULT_REGION = "us-east-1"
    EB_APP_NAME  = "dla-juiceshop-app"
    EB_ENV_NAME  = "dla-juiceshop-env"
    ECS_CLUSTER  = "dla-juiceshop-cluster"
    ECS_SERVICE  = "dla-juiceshop-service"
    K8S_NAMESPACE = "juice-shop"
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT[0..6]}"
          echo "Image tag: ${env.IMAGE_TAG}"
        }
      }
    }

    stage('Build Image') {
      steps {
        sh """
          docker build \
            -f Dockerfile.dlagroup \
            -t ${GHCR_REPO}:${IMAGE_TAG} \
            -t ${GHCR_REPO}:latest \
            -t ${GITEA_REPO}:${IMAGE_TAG} \
            -t ${GITEA_REPO}:latest \
            .
        """
      }
    }

    stage('Push to GHCR') {
      steps {
        withCredentials([string(credentialsId: 'ghcr-token', variable: 'GHCR_TOKEN')]) {
          sh """
            echo \$GHCR_TOKEN | docker login ghcr.io -u arieldla --password-stdin
            docker push ${GHCR_REPO}:${IMAGE_TAG}
            docker push ${GHCR_REPO}:latest
          """
        }
      }
    }

    stage('Push to Gitea') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'gitea-registry',
                          usernameVariable: 'GITEA_USER',
                          passwordVariable: 'GITEA_PASS')]) {
          sh """
            echo \$GITEA_PASS | docker login 192.168.0.102:3000 -u \$GITEA_USER --password-stdin
            docker push ${GITEA_REPO}:${IMAGE_TAG}
            docker push ${GITEA_REPO}:latest
          """
        }
      }
    }

    stage('Update K8s Manifest') {
      steps {
        sh """
          sed -i 's|image: ghcr.io/arieldla/juice-shop:.*|image: ${GHCR_REPO}:${IMAGE_TAG}|' k8s/deployment.yaml
          git config user.email "jenkins@dlagroup.io"
          git config user.name  "Jenkins"
          git add k8s/deployment.yaml
          git commit -m "ci: update juice-shop image to ${IMAGE_TAG} [skip ci]" || true
        """
        withCredentials([string(credentialsId: 'github-token', variable: 'GH_TOKEN')]) {
          sh """
            git push https://arieldla:\$GH_TOKEN@github.com/arieldla/juice-shop-lab.git HEAD:master
          """
        }
      }
    }

    stage('AWS Auth (IAM Roles Anywhere)') {
      steps {
        withCredentials([
          string(credentialsId: 'iam-roles-anywhere-trust-anchor-arn', variable: 'TRUST_ANCHOR_ARN'),
          string(credentialsId: 'iam-roles-anywhere-profile-arn',      variable: 'PROFILE_ARN'),
          string(credentialsId: 'iam-roles-anywhere-role-arn',         variable: 'ROLE_ARN')
        ]) {
          sh '''
            aws_signing_helper credential-process \
              --certificate  /opt/jenkins-pki/jenkins.crt \
              --private-key  /opt/jenkins-pki/jenkins.key \
              --trust-anchor-arn $TRUST_ANCHOR_ARN \
              --profile-arn      $PROFILE_ARN \
              --role-arn         $ROLE_ARN \
              > /tmp/aws-creds.json
            export AWS_ACCESS_KEY_ID=$(jq -r .AccessKeyId      /tmp/aws-creds.json)
            export AWS_SECRET_ACCESS_KEY=$(jq -r .SecretAccessKey /tmp/aws-creds.json)
            export AWS_SESSION_TOKEN=$(jq -r .SessionToken      /tmp/aws-creds.json)
            aws sts get-caller-identity
          '''
        }
      }
    }

    stage('Deploy to ECS') {
      steps {
        sh """
          aws ecs update-service \
            --cluster  ${ECS_CLUSTER} \
            --service  ${ECS_SERVICE} \
            --force-new-deployment \
            --region   ${AWS_REGION}
        """
      }
    }

    stage('Deploy to Elastic Beanstalk') {
      steps {
        sh """
          cd eb
          zip -r ../juice-shop-eb-${IMAGE_TAG}.zip Dockerrun.aws.json
          aws s3 cp ../juice-shop-eb-${IMAGE_TAG}.zip \
            s3://dlagroup-lab-artifacts/eb-lab/juice-shop-eb-${IMAGE_TAG}.zip

          aws elasticbeanstalk create-application-version \
            --application-name ${EB_APP_NAME} \
            --version-label    ${IMAGE_TAG} \
            --source-bundle    S3Bucket=dlagroup-lab-artifacts,S3Key=eb-lab/juice-shop-eb-${IMAGE_TAG}.zip \
            --region           ${AWS_REGION}

          aws elasticbeanstalk update-environment \
            --application-name  ${EB_APP_NAME} \
            --environment-name  ${EB_ENV_NAME} \
            --version-label     ${IMAGE_TAG} \
            --region            ${AWS_REGION} || echo "EB env not running - skipping"
        """
      }
    }

    stage('Verify Health') {
      steps {
        sh """
          sleep 20
          curl -sf --retry 5 --retry-delay 10 \
            http://k8s-master01:32744 -H 'Host: juice-k8s.dlagroup.io' \
            | grep -o 'Juice Shop' && echo "K8s: OK"
        """
      }
    }

    stage('Notify') {
      steps {
        sh """
          aws sns publish \
            --topic-arn arn:aws:sns:us-east-1:640168421612:dla-pipeline-approvals \
            --message   "juice-shop build ${IMAGE_TAG} deployed successfully" \
            --subject   "DLAGROUP CI: juice-shop ${IMAGE_TAG}" \
            --region    ${AWS_REGION}
        """
      }
    }
  }

  post {
    always {
      sh 'docker image prune -f || true'
      sh 'rm -f /tmp/aws-creds.json || true'
    }
    failure {
      echo "Pipeline failed — check stage logs above"
    }
  }
}
