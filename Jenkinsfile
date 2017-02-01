node('WinDocker') {
    // JenkinsFile Groovy-based PipeLine workflow for Jenkins-CI
    // Documentation:  https://jenkins.io/doc/pipeline/
    
    stage('Checkout'){
		// Can't sync PowerShell 
		dir('C:\\PowerShell') {
            scm checkout 
        }
	}
    stage('SpinUpContainer'){
        bat 'set'
        bat 'docker create -i --name %BUILD_ID% -h PoshCore -v c:\\PowerShell:c:\\PowerShell brycem/windowsservercore:latest echo hello world;exit'
        bat 'docker cp "%WORKSPACE%\\Tools" %BUILD_ID%:"C:\\PowerShell\\Tools"'
        bat 'docker start %BUILD_ID%'
    }
	stage('Test'){
		//bat 'docker exec %BUILD_ID% powershell.exe -c "C:\\PowerShell\\Tools\\Jenkins.ps1 -Test"'
    }
    stage('StopContainer'){
        bat 'docker stop %BUILD_ID%'
    }
	stage('Archive'){
		archive 'C:\\PowerShell'
		bat 'docker rm %BUILD_ID%'
		mail bcc: '', body: '', cc: '', from: '', replyTo: '', subject: '', to: ''
    }
}
node('Lability') {
    stage('Checkout'){
        // Can't sync PowerShell 
        dir('C:\\PowerShell') {
            scm checkout 
        }
    }
}