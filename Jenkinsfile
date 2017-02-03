node('WinDocker') {
    // JenkinsFile Groovy-based PipeLine workflow for Jenkins-CI
    // Documentation:  https://jenkins.io/doc/pipeline/
    
    stage('SpinUpContainer'){
        bat 'set'
        bat 'docker create -i --name %BUILD_TAG% -h PoshCore -v C:\\Jenkins\\Tools:c:\\PowerShell\\Tools brycem/windowsservercore:latest echo hello world;exit'
        bat 'docker start %BUILD_TAG%'
    }
	stage('Test'){
		bat 'docker exec %BUILD_TAG% powershell.exe -c "C:\\PowerShell\\Tools\\Jenkins.ps1 -Test"'
		bat 'echo artifact>%WORKSPACE%\\docker.log'
    }
	stage('Archive'){
		bat 'docker stop %BUILD_TAG%'
		archiveArtifacts '*.log'
		bat 'docker rm %BUILD_TAG%'
		//mail bcc: '', body: '$PROJECT_NAME - Build # $BUILD_NUMBER - $BUILD_STATUS:  Check console output at $BUILD_URL to view the results.', cc: '', from: '', replyTo: '', subject: '$PROJECT_NAME - Build # $BUILD_NUMBER - $BUILD_STATUS!', to: 'brycem@microsoft.com'
    }
}
node('Lability') {
    stage('Checkout'){
        bat 'set'
        bat 'echo artifact>%WORKSPACE%\\docker.log'
        archiveArtifacts '*.log'
    }
}