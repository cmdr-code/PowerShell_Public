# Progress Bar for Copy-Item
After selecting the folder, we save the total number of files.

:
#Get all the text files in the folder
$files = Get-ChildItem $selectedPath -Filter *.txt;
:

Next, we use the saved total files to initialize the progress bar Maximum property. Then we initialize all other properties before starting to display the progress activity.

#Initialize the Progress Bar
$progressbar1.Maximum = $files.Count;
$progressbar1.Step = 1;
$progressbar1.Value = 0;

The progress bar will start with Value property = 0, and use the Step property to increment that Value by 1 when executing the for-each loop. The progress bar will start to increment.

#Copy the files and update the progress bar
$cnt = 1;
foreach ($file in $files)
{
Copy-Item ('{0}\\{1}' -f $selectedPath, $file) -Destination $destination;
$copiedfiles = "$cnt - $($file.name) - copied from $($selectedPath) to $($destination).";
$richtextbox1.AppendText(($copiedfiles | Out-String -Width 1000));
$cnt++;

## - Progress bar method to increment the slider:
$progressbar1.PerformStep();

};
