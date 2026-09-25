package com.example.ui.coderdroid

import org.eclipse.jgit.api.Git
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class CdrGitServiceTest {
    @get:Rule val temp = TemporaryFolder()
    @Test fun deletedFilesCanBeStagedAndCommitted() {
        val root=temp.newFolder()
        Git.init().setDirectory(root).call().close()
        val file=File(root,"notes.txt").apply { writeText("hello") }
        CdrGitService.stageAll(root).getOrThrow()
        CdrGitService.commit(root,"Initial","Test User","test@example.invalid").getOrThrow()
        file.delete()
        CdrGitService.stageAll(root).getOrThrow()
        assertTrue(CdrGitService.status(root).staged.any {it.path=="notes.txt" && it.kind==CdrGitFileStatus.Kind.DELETED})
        CdrGitService.commit(root,"Remove notes","Test User","test@example.invalid").getOrThrow()
        assertFalse(CdrGitService.status(root).hasChanges)
    }
    @Test fun commitRequiresRealIdentity() {
        val root=temp.newFolder();Git.init().setDirectory(root).call().close()
        File(root,"readme").writeText("hello");CdrGitService.stageAll(root).getOrThrow()
        assertTrue(CdrGitService.commit(root,"message","","bad").isFailure)
        assertTrue(CdrGitService.status(root).staged.isNotEmpty())
    }
    @Test fun failedClonePreservesExistingNonGitFolder() {
        val root=temp.newFolder();File(root,"valuable.txt").writeText("keep me")
        assertTrue(CdrGitService.clone(root,"https://github.com/example/missing.git","","").isFailure)
        assertEquals("keep me",File(root,"valuable.txt").readText())
    }
    @Test fun cloneRejectsEmbeddedCredentialsBeforeNetwork() {
        val dest=File(temp.root,"clone")
        assertTrue(CdrGitService.clone(dest,"https://user:secret@github.com/example/repo.git","","").isFailure)
        assertFalse(dest.exists())
    }
    @Test fun savedCredentialsCannotBeSentToAnotherHost() {
        val root=temp.newFolder()
        Git.init().setDirectory(root).call().use { it.repository.config.apply {setString("remote","origin","url","https://example.invalid/repo.git");save()} }
        val result=CdrGitService.push(root,"user","secret")
        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull()?.message.orEmpty().contains("github.com"))
    }
}
