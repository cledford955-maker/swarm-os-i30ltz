package com.swarm.lucille.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.swarm.lucille.ui.theme.CarbonSurfaceVariant
import com.swarm.lucille.ui.theme.NvidiaGreen
import com.swarm.lucille.R

@Composable
fun DrI3oltzSmallAvatar(size: Int = 48) {
    Box(
        modifier = Modifier
            .size(size.dp)
            .clip(CircleShape)
            .background(CarbonSurfaceVariant)
            .border(2.dp, NvidiaGreen.copy(alpha = 0.8f), CircleShape),
        contentAlignment = Alignment.Center
    ) {
        Image(
            painter = painterResource(id = R.drawable.dr_i3oltz_3d_avatar),
            contentDescription = "DR. I30LTZ 3D Avatar",
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )
    }
}

