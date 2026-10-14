local SFX = {}

function SFX.FadeSound(sound, targetVolume, duration, steps)
	if sound and sound:IsA("Sound") then
		if not targetVolume then targetVolume = 0 end
		if not duration then duration = 1 end
		if not steps then steps = 60 end
		task.spawn(function()
			local interval = duration / steps
			local initialVolume = sound.Volume
			local volumeChange = targetVolume - initialVolume

			for i = 1, steps do
				sound.Volume = initialVolume + (volumeChange * (i / steps))
				task.wait(interval)
			end

			sound.Volume = targetVolume -- Ensure it reaches the exact target value
		end)
	end
end


return SFX
