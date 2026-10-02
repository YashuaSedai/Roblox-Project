local SFX = {}

function SFX.FadeSound(sound, targetVolume, duration, steps)
	if sound and sound:IsA("Sound") then
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
