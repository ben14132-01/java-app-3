pipeline {
    agent {
        label 'windows'
    }

    environment {
        DOCKERHUB_USERNAME = credentials('DOCKERHUB_USERNAME')
        DOCKERHUB_TOKEN = credentials('DOCKERHUB_TOKEN')
        SONAR_TOKEN = credentials('SONAR_TOKEN_BEN')
        GITHUB_TOKEN = credentials('GITHUB_TOKEN_BEN')
        SNYK_TOKEN = credentials('SNYK_TOKEN_BEN')
        COMMIT_ID = "${env.GIT_COMMIT.take(6)}"
    }

    parameters {
        booleanParam(name: 'SNYK', defaultValue: true, description: 'Perform Snyk Scan')
        booleanParam(name: 'SONARQUBE', defaultValue: false, description: 'Perform SonarQube Scan')
        booleanParam(name: 'GITLEAKS', defaultValue: false, description: 'Perform Gitleaks Scan')
        booleanParam(name: 'TRIVY', defaultValue: false, description: 'Perform Trivy Scan')
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }


        stage('Set Commit ID') {
            steps {
                script {
                    env.COMMIT_ID = env.GIT_COMMIT.take(6)
                    echo "COMMIT_ID set to: ${env.COMMIT_ID}"
                }
            }
        }

        stage('Snyk Scan') {
            when {
                expression {params.SNYK}
            }
            steps {
                script {
                    bat """
                        snyk auth %SNYK_TOKEN%
                        snyk test 
                        snyk monitor 
                    """
                }
            }
        }

        stage('Gitleaks') {
            when {
                expression {params.GITLEAKS}
            }
            steps {
                script {
                    bat '''
                        wsl gitleaks detect --source . -r gitleaks-report.json -f json
                    '''
                }
            }
        }

        stage('Commit Gitleaks Results') {
            when {
                expression {params.GITLEAKS}
            }
            steps {
                script {
                    bat """
                        wsl git config user.email blee070@e.ntu.edu.sg
                        wsl git config user.name "%DOCKERHUB_USERNAME%"
                        wsl git remote set-url origin https://%DOCKERHUB_USERNAME%:%GITHUB_TOKEN%@github.com/ben14132-01/java-app-3.git
                        wsl git add gitleaks-report.json
                        wsl git commit -m "Add Gitleaks security scan results for commit ${env.COMMIT_ID}" || echo "No changes to commit"
                        wsl git push origin HEAD:main
                    """
                }
            }
        }

        stage('Create SonarQube Project') {
            when {
                expression {params.SONARQUBE}
            }
            steps {
                script {
                    def response = bat(
                        script: '''
                        curl -X POST ^
                        -u admin:admin ^
                        "http://localhost:9001/api/projects/create?project=java-app-3&name=java-app-3"
                        ''',
                        returnStatus: true
                    )
                    
                    if (response == 0) {
                        echo "SonarQube project created successfully"
                    } else if (response == 22) {
                        echo "Project already exists or other HTTP error - continuing..."
                    } else {
                        error "Failed to create SonarQube project"
                    }
                }
            }
        }


        stage('SonarQube Analysis') {
            when {
                expression {params.SONARQUBE}
            }
            steps {
                dir('src/SpringAPI') {
                    bat '''
                    mvn clean verify sonar:sonar "-Dsonar.projectKey=java-app-3" "-Dsonar.projectName='java-app-3'" "-Dsonar.host.url=http://localhost:9001" "-Dsonar.token=%SONAR_TOKEN%"
                    '''
                }
            }
        }


        stage('Login to Docker Hub') {
            steps {
                bat '''
                    echo %DOCKERHUB_TOKEN% | docker login --username %DOCKERHUB_USERNAME% --password-stdin
                '''
            }
        }

        // stage('Debug Directory Structure') {
        //     steps {
        //         bat '''
        //             echo "Root directory:"
        //             dir
        //             echo "src directory"
        //             dir src\\
        //             echo "springapi dir"
        //             dir src\\SpringAPI
        //             echo "target dir"
        //             dir src\\SpringAPI\\target
        //         '''
        //     }
        // }

        stage('Build and Push Docker Image') {
            steps {
                script {
                    def appName = 'java-app-3' //need to change appname
                    bat """
                        docker build -t %DOCKERHUB_USERNAME%/${appName}:${env.COMMIT_ID} .
                        docker push %DOCKERHUB_USERNAME%/${appName}:${env.COMMIT_ID}
                    """
                }
            }
        }

        stage('Trivy Scan') {
            when {
                expression {params.TRIVY}
            }
            steps {
                script {
                    def appName = 'java-app-3' 
                    bat """
                        wsl trivy image --format json --output trivyResults.json --insecure %DOCKERHUB_USERNAME%/${appName}:${env.COMMIT_ID} 
                    """
                }
            }
        }

        stage('Commit Trivy Results') {
            when {
                expression {params.TRIVY}
            }
            steps {
                script {
                    bat """
                        wsl git config user.email blee070@e.ntu.edu.sg
                        wsl git config user.name "%DOCKERHUB_USERNAME%"
                        wsl git remote set-url origin https://%DOCKERHUB_USERNAME%:%GITHUB_TOKEN%@github.com/ben14132-01/java-app-3.git
                        wsl git add trivyResults.json
                        wsl git commit -m "Add Trivy security scan results for commit ${env.COMMIT_ID}" || echo "No changes to commit"
                        wsl git push origin HEAD:main
                    """
                }
            }
        }

        stage('Deploy with Helm') {
            steps {
                script {
                    def commitId = env.COMMIT_ID //change java-app-9 here
                    bat """
                        wsl helm upgrade --install java-app ./charts/java-app-3 -n java --create-namespace --set image.tag=${commitId}
                    """
                }
            }
        }
    }

    post {
        always {
            bat 'docker logout'
        }
    }
}