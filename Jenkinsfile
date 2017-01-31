node('WinDocker') {
    // JenkinsFile Groovy-based PipeLine workflow for Jenkins-CI
    // Documentation:  https://jenkins.io/doc/pipeline/

    stage('SpinUpContainer'){
        bat 'docker create -i --name %BUILD_ID% -h PoshCore brycem/windowsservercore:latest echo hello world;exit'
        bat 'docker cp "${env.WORKSPACE}\\Tools" ${env.BUILD_ID}:"C:\\PowerShell\\Tools"'
        // bat 'docker cp "C:\\Program Files\\PowerShell" ${env.BUILD_ID}:"C:\\PowerShell"'
        // bat 'docker cp "${env.WORKSPACE}\\Test" ${env.BUILD_ID}:"C:\\PowerShell\\Test"'
        bat 'docker start ${env.BUILD_ID}'
    }
	stage('UpdateTools'){
		//bat 'docker exec ${env.BUILD_ID} powershell.exe -c "C:\\PowerShell\\Tools\\Jenkins.ps1 -UpdateTools"'
    }
	stage('Test'){
		//bat 'docker exec ${env.BUILD_ID} powershell.exe -c "C:\\PowerShell\\Tools\\Jenkins.ps1 -Test"'
    }
    stage('StopContainer'){
        bat 'docker stop ${env.BUILD_ID}'
    }
	stage('Archive'){
		// archive 'PowerShell/**'
		bat 'docker rm ${env.BUILD_ID}'
    }
}
