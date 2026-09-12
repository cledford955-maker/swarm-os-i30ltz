import java.util.regex.Pattern

fun main() {
    val text = "SWARM_OS THE LUCILLE NATIVE OS"
    val regex = Regex("LUCILLE|OS")
    var lastIndex = 0
    regex.findAll(text).forEach { matchResult ->
        println("Green: ${text.substring(lastIndex, matchResult.range.first)}")
        println("Purple: ${matchResult.value}")
        lastIndex = matchResult.range.last + 1
    }
    println("Green: ${text.substring(lastIndex)}")
}
