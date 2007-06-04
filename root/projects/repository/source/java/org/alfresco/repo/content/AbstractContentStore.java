/*
 * Copyright (C) 2005-2007 Alfresco Software Limited.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

 * As a special exception to the terms and conditions of version 2.0 of 
 * the GPL, you may redistribute this Program in connection with Free/Libre 
 * and Open Source Software ("FLOSS") applications as described in Alfresco's 
 * FLOSS exception.  You should have recieved a copy of the text describing 
 * the FLOSS exception, and it is also available here: 
 * http://www.alfresco.com/legal/licensing"
 */
package org.alfresco.repo.content;

import java.util.Calendar;
import java.util.GregorianCalendar;
import java.util.Set;

import org.alfresco.error.AlfrescoRuntimeException;
import org.alfresco.service.cmr.repository.ContentIOException;
import org.alfresco.service.cmr.repository.ContentReader;
import org.alfresco.service.cmr.repository.ContentWriter;
import org.alfresco.util.GUID;

/**
 * Base class providing support for different types of content stores.
 * <p>
 * Since content URLs have to be consistent across all stores for
 * reasons of replication and backup, the most important functionality
 * provided is the generation of new content URLs and the checking of
 * existing URLs.
 * 
 * @author Derek Hulley
 */
public abstract class AbstractContentStore implements ContentStore
{
    /**
     * Creates a new content URL.  This must be supported by all
     * stores that are compatible with Alfresco.
     * 
     * @return Returns a new and unique content URL
     */
    public static String createNewUrl()
    {
        Calendar calendar = new GregorianCalendar();
        int year = calendar.get(Calendar.YEAR);
        int month = calendar.get(Calendar.MONTH) + 1;  // 0-based
        int day = calendar.get(Calendar.DAY_OF_MONTH);
        int hour = calendar.get(Calendar.HOUR_OF_DAY);
        int minute = calendar.get(Calendar.MINUTE);
        // create the URL
        StringBuilder sb = new StringBuilder(20);
        sb.append(STORE_PROTOCOL)
          .append(year).append('/')
          .append(month).append('/')
          .append(day).append('/')
          .append(hour).append('/')
          .append(minute).append('/')
          .append(GUID.generate()).append(".bin");
        String newContentUrl = sb.toString();
        // done
        return newContentUrl;
    }
    
    /**
     * This method can be used to ensure that URLs conform to the
     * required format.  If subclasses have to parse the URL,
     * then a call to this may not be required - provided that
     * the format is checked.
     * <p>
     * The protocol part of the URL (including legacy protocols)
     * is stripped out and just the relative path is returned.
     * 
     * @param contentUrl a URL of the content to check
     * @return Returns the relative part of the URL
     * @throws RuntimeException if the URL is not correct
     * 
     * @deprecated  Stores can really have any prefix in the URL.  This method was
     *              really specific to the FileContentStore and has been moved into
     *              it.
     */
    public static String getRelativePart(String contentUrl) throws RuntimeException
    {
        int index = 0;
        if (contentUrl.startsWith(STORE_PROTOCOL))
        {
            index = 8;
        }
        else if (contentUrl.startsWith("file://"))
        {
            index = 7;
        }
        else
        {
            throw new AlfrescoRuntimeException(
                    "All content URLs must start with " + STORE_PROTOCOL + ": \n" +
                    "   the invalid url is: " + contentUrl);
        }
        
        // extract the relative part of the URL
        String path = contentUrl.substring(index);
        // more extensive checks can be added in, but it seems overkill
        if (path.length() < 8)
        {
            throw new AlfrescoRuntimeException(
                    "The content URL is invalid: \n" +
                    "   content url: " + contentUrl);
        }
        return path;
    }

    /**
     * Simple implementation that uses the
     * {@link ContentReader#exists() reader's exists} method as its implementation.
     */
    public boolean exists(String contentUrl) throws ContentIOException
    {
        ContentReader reader = getReader(contentUrl);
        return reader.exists();
    }

    /**
     * Searches for URLs using null dates.
     * 
     * @see ContentStore#getUrls(java.util.Date, java.util.Date)
     */
    public final Set<String> getUrls() throws ContentIOException
    {
        return getUrls(null, null);
    }

    /**
     * @see ContentContext
     * @see ContentStore#getWriter(ContentContext)
     */
    public final ContentWriter getWriter(ContentReader existingContentReader, String newContentUrl) throws ContentIOException
    {
        ContentContext ctx = new ContentContext(existingContentReader, newContentUrl);
        return getWriter(ctx);
    }
}
