// WorkspaceScreen.kt — Drive | Calendar | Contacts workspace  v1.0.0  2026-09-24
package com.swarm.lucille.ui.screen

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.swarm.lucille.data.network.*
import com.swarm.lucille.ui.theme.*
import com.swarm.lucille.ui.viewmodel.MainViewModel

@Composable
fun WorkspaceScreen(vm: MainViewModel) {
    var tab by remember { mutableStateOf(0) }
    val tabs = listOf("DRIVE", "CALENDAR", "CONTACTS")

    Column(modifier = Modifier.fillMaxSize().background(SwarmBg)) {
        TabRow(
            selectedTabIndex = tab,
            containerColor   = SwarmSurface,
            contentColor     = SwarmCyan,
            indicator = { pos ->
                TabRowDefaults.SecondaryIndicator(
                    modifier = Modifier.tabIndicatorOffset(pos[tab]),
                    color    = SwarmCyan
                )
            }
        ) {
            tabs.forEachIndexed { i, label ->
                Tab(
                    selected = tab == i,
                    onClick  = { tab = i },
                    text = {
                        Text(label, style = MaterialTheme.typography.labelLarge,
                            color = if (tab == i) SwarmCyan else TextDisabled)
                    }
                )
            }
        }

        when (tab) {
            0 -> DriveTab(vm)
            1 -> CalendarTab(vm)
            2 -> ContactsTab(vm)
        }
    }
}

// ─── Drive ────────────────────────────────────────────────────────────────────

@Composable
fun DriveTab(vm: MainViewModel) {
    val state    by vm.driveRecent.collectAsStateWithLifecycle()
    var query    by remember { mutableStateOf("") }
    var searching by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { vm.loadDriveRecent() }

    Column(modifier = Modifier.fillMaxSize()) {
        // Search bar
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            placeholder = { Text("Search Drive…") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = {
                if (query.isNotBlank()) vm.searchDrive(query)
                else vm.loadDriveRecent(true)
            }),
            trailingIcon = {
                if (query.isNotBlank()) {
                    TextButton(onClick = { query = ""; vm.loadDriveRecent(true) }) {
                        Text("✕", color = TextSecondary)
                    }
                }
            },
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor   = SwarmPurple,
                unfocusedBorderColor = SwarmBorder,
                cursorColor          = SwarmCyan
            )
        )

        when {
            state.loading    -> SwarmLoading("Loading Drive…")
            state.error != null -> SwarmError(state.error!!) { vm.loadDriveRecent(true) }
            else -> {
                val files = state.data?.files ?: emptyList()
                if (files.isEmpty()) {
                    SwarmEmpty("No files found") { vm.loadDriveRecent() }
                } else {
                    LazyVerticalGrid(
                        columns = GridCells.Fixed(2),
                        contentPadding = PaddingValues(12.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalArrangement   = Arrangement.spacedBy(10.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        items(files, key = { it.id }) { f ->
                            DriveFileCard(f)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun DriveFileCard(file: DriveFile) {
    Column(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(SwarmSurface2)
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(file.icon, fontSize = 28.sp)
        Text(
            file.name,
            style    = MaterialTheme.typography.bodyMedium,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
        Text(
            file.modifiedTime?.take(10) ?: "",
            style = MaterialTheme.typography.labelSmall
        )
    }
}

// ─── Calendar ─────────────────────────────────────────────────────────────────

@Composable
fun CalendarTab(vm: MainViewModel) {
    val state by vm.calendar.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { vm.loadCalendar() }

    when {
        state.loading    -> SwarmLoading("Loading calendar…")
        state.error != null -> SwarmError(state.error!!) { vm.loadCalendar(true) }
        else -> {
            val events = state.data?.events?.items ?: emptyList()
            if (events.isEmpty()) {
                SwarmEmpty("No upcoming events") { vm.loadCalendar(true) }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    item {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            SectionHeader("📅 UPCOMING (7 days)")
                            TextButton(onClick = { vm.loadCalendar(true) }) {
                                Text("↺", color = SwarmCyan)
                            }
                        }
                    }
                    items(events, key = { it.id }) { event ->
                        CalEventCard(event)
                    }
                }
            }
        }
    }
}

@Composable
fun CalEventCard(event: CalEvent) {
    SwarmCard {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            // Time column
            Column(
                modifier = Modifier.width(52.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                val start = event.start?.display ?: ""
                val datePart = start.take(10)
                val timePart = if (start.length > 10) start.drop(11) else ""
                Text(datePart.takeLast(5), style = MaterialTheme.typography.labelLarge, color = SwarmCyan)
                if (timePart.isNotBlank()) {
                    Text(timePart, style = MaterialTheme.typography.labelSmall)
                }
            }
            // Event info
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(event.summary ?: "Untitled event",
                    style = MaterialTheme.typography.headlineSmall)
                event.location?.let {
                    Text("📍 $it", style = MaterialTheme.typography.bodySmall, color = TextSecondary)
                }
                event.description?.let {
                    Text(it, style = MaterialTheme.typography.bodySmall,
                        maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

// ─── Contacts ─────────────────────────────────────────────────────────────────

@Composable
fun ContactsTab(vm: MainViewModel) {
    val state by vm.contacts.collectAsStateWithLifecycle()
    var query by remember { mutableStateOf("") }

    LaunchedEffect(Unit) { vm.loadContacts() }

    Column(modifier = Modifier.fillMaxSize()) {
        // Search bar
        OutlinedTextField(
            value = query,
            onValueChange = {
                query = it
                if (it.length >= 2) vm.searchContacts(it)
                else if (it.isBlank()) vm.loadContacts(true)
            },
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            placeholder = { Text("Search contacts…") },
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor   = SwarmPurple,
                unfocusedBorderColor = SwarmBorder,
                cursorColor          = SwarmCyan
            )
        )

        when {
            state.loading    -> SwarmLoading("Loading contacts…")
            state.error != null -> SwarmError(state.error!!) { vm.loadContacts(true) }
            else -> {
                val contacts = (state.data?.contacts ?: emptyList()) +
                    (state.data?.connections ?: emptyList())
                if (contacts.isEmpty()) {
                    SwarmEmpty("No contacts found") { vm.loadContacts(true) }
                } else {
                    LazyColumn(contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp)) {
                        item {
                            Text("${contacts.size} contacts", style = MaterialTheme.typography.labelMedium,
                                modifier = Modifier.padding(bottom = 8.dp))
                        }
                        items(contacts, key = { it.resourceName ?: it.displayOrName }) { c ->
                            ContactRow(c)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ContactRow(c: com.swarm.lucille.data.network.Contact) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(SwarmPurple.copy(0.4f)),
            contentAlignment = Alignment.Center
        ) {
            Text(c.initials, style = MaterialTheme.typography.labelLarge, color = TextPrimary)
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(c.displayOrName, style = MaterialTheme.typography.headlineSmall)
            c.email?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = TextSecondary) }
            c.phone?.let { Text(it, style = MaterialTheme.typography.labelMedium, color = SwarmCyan) }
        }
    }
    HorizontalDivider(color = SwarmBorder, thickness = 0.5.dp)
}
