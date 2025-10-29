pipeline {
  agent any
  stages {
    stage('Build and Push') {
      steps {
        script {
          def tags = ["oracle", "microsoft", "google", "meta", "ibm", "amazon", "apple", "openai"]
          for (t in tags) {
            sh "docker build -t cutthecheck/enterprise_automation:${t} ."
            sh "docker push cutthecheck/enterprise_automation:${t}"
          }
        }
      }
    }
  }
}
