
/*
 * DVD Store 3.5 MySQL Functions using stored procedures - ds35mysqlspfns.cs
 *
 * Copyright (C) 2025 Red Hat Inc. <dyeisley@redhat.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA  
 */

using System;
using System.IO;
using System.Data;
using MySql.Data.MySqlClient;
using System.Net;
using System.Threading;
using System.Runtime.InteropServices;

namespace ds2xdriver
  {
  /// <summary>
  /// ds35mysqlspfns.cs: DVD Store 3.5 MySql Functions
  /// </summary>
  public class ds2Interface
    {
#if (USE_WIN32_TIMER)
    [DllImport("kernel32.dll")]
    extern static short QueryPerformanceCounter(ref long x);
    [DllImport("kernel32.dll")]
    extern static short QueryPerformanceFrequency(ref long x);  
#endif

    int ds2Interfaceid;
    MySqlConnection objConn;
    string conn_str = "";
    string target_server_name;
    int target_store_number = 1; //Added to support Multiple stores - default is 1

    MySqlCommand Login, New_Customer, New_Member, New_Review, New_Helpfulness, Purchase;
    MySqlCommand BrowseReviews_by_title, BrowseReviews_by_actor, Get_Prod_Reviews, Get_Reviews_by_stars;
    MySqlCommand Get_Reviews_by_date, Browse_by_title, Browse_by_actor, Browse_by_category;
    MySqlParameter cust_out_param, member_out_param, reviewid_out_param, helpfulnessid_out_param, neworder_out_param;

//
//-------------------------------------------------------------------------------------------------
// 
    // (Overloaded constructor to support multiple stores within single DS3 instance)
    public ds2Interface(int ds2interfaceid, string target_name, int target_store)
    {
      ds2Interfaceid = ds2interfaceid;
      target_server_name = target_name;
      target_store_number = target_store;
      conn_str = "Server=" + target_server_name + ";User ID=web;Password=web;Database=DS3";
      objConn = new MySqlConnection(conn_str);

      cust_out_param = new MySqlParameter("customerid_out", MySqlDbType.Int32);
      cust_out_param.Direction = ParameterDirection.Output;
      cust_out_param.Value = 0;

      member_out_param = new MySqlParameter("customerid_out", MySqlDbType.Int32);
      member_out_param.Direction = ParameterDirection.Output;
      member_out_param.Value = 0;

      reviewid_out_param = new MySqlParameter("review_id_out", MySqlDbType.Int32);
      reviewid_out_param.Direction = ParameterDirection.Output;
      reviewid_out_param.Value = 0;

      helpfulnessid_out_param = new MySqlParameter("review_helpfulness_id_out", MySqlDbType.Int32);
      helpfulnessid_out_param.Direction = ParameterDirection.Output;
      helpfulnessid_out_param.Value = 0;

      neworder_out_param = new MySqlParameter("neworderid_out", MySqlDbType.Int32);
      neworder_out_param.Direction = ParameterDirection.Output;
      neworder_out_param.Value = 0;

      // Set up MySql stored procedure calls and associated parameters
      Login = new MySqlCommand("LOGIN" + target_store_number, objConn);
      Login.CommandType = CommandType.StoredProcedure;
      Login.Parameters.Add("username_in", MySqlDbType.VarChar, 50);
      Login.Parameters.Add("password_in", MySqlDbType.VarChar, 50);

      New_Customer = new MySqlCommand("NEW_CUSTOMER" + target_store_number, objConn);
      New_Customer.CommandType = CommandType.StoredProcedure;
      New_Customer.Parameters.Add("username_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("password_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("firstname_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("lastname_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("address1_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("address2_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("city_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("state_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("zip_in", MySqlDbType.Int32);
      New_Customer.Parameters.Add("country_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("region_in", MySqlDbType.Int32);
      New_Customer.Parameters.Add("email_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("phone_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("creditcardtype_in", MySqlDbType.Int32);
      New_Customer.Parameters.Add("creditcard_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("creditcardexpiration_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("age_in", MySqlDbType.Byte);
      New_Customer.Parameters.Add("income_in", MySqlDbType.Int32);
      New_Customer.Parameters.Add("gender_in", MySqlDbType.VarChar, 1);
      New_Customer.Parameters.Add(cust_out_param);

      New_Member = new MySqlCommand("NEW_MEMBER" + target_store_number, objConn);
      New_Member.CommandType = CommandType.StoredProcedure; 
      New_Member.Parameters.Add("customerid_in", MySqlDbType.Int32);
      New_Member.Parameters.Add("membershiplevel_in", MySqlDbType.Int32);
      New_Member.Parameters.Add(member_out_param);

      New_Review = new MySqlCommand("NEW_PROD_REVIEW" + target_store_number, objConn);
      New_Review.CommandType = CommandType.StoredProcedure;
      New_Review.Parameters.Add("prod_id_in", MySqlDbType.Int32);
      New_Review.Parameters.Add("stars_in", MySqlDbType.Int32);
      New_Review.Parameters.Add("customerid_in", MySqlDbType.Int32);
      New_Review.Parameters.Add("review_summary_in", MySqlDbType.VarChar, 50);
      New_Review.Parameters.Add("review_text_in", MySqlDbType.VarChar, 1000);
      New_Review.Parameters.Add(reviewid_out_param);

      New_Helpfulness = new MySqlCommand("NEW_REVIEW_HELPFULNESS" + target_store_number, objConn);
      New_Helpfulness.CommandType = CommandType.StoredProcedure;
      New_Helpfulness.Parameters.Add("review_id_in", MySqlDbType.Int32);
      New_Helpfulness.Parameters.Add("customerid_in", MySqlDbType.Int32);
      New_Helpfulness.Parameters.Add("review_helpfulness_in", MySqlDbType.Int32);
      New_Helpfulness.Parameters.Add(helpfulnessid_out_param);

      Purchase = new MySqlCommand("PURCHASE" + target_store_number, objConn);
      Purchase.CommandType = CommandType.StoredProcedure;
      Purchase.Parameters.Add("customerid_in", MySqlDbType.Int32);
      Purchase.Parameters.Add("number_items", MySqlDbType.Int32);
      Purchase.Parameters.Add("netamount_in", MySqlDbType.Decimal);
      Purchase.Parameters.Add("taxamount_in", MySqlDbType.Decimal);
      Purchase.Parameters.Add("totalamount_in", MySqlDbType.Decimal);
      Purchase.Parameters.Add("prod_id_in0", MySqlDbType.Int32); Purchase.Parameters.Add("qty_in0", MySqlDbType.Int32);
      Purchase.Parameters.Add("prod_id_in1", MySqlDbType.Int32); Purchase.Parameters.Add("qty_in1", MySqlDbType.Int32);
      Purchase.Parameters.Add("prod_id_in2", MySqlDbType.Int32); Purchase.Parameters.Add("qty_in2", MySqlDbType.Int32);
      Purchase.Parameters.Add("prod_id_in3", MySqlDbType.Int32); Purchase.Parameters.Add("qty_in3", MySqlDbType.Int32);
      Purchase.Parameters.Add("prod_id_in4", MySqlDbType.Int32); Purchase.Parameters.Add("qty_in4", MySqlDbType.Int32);
      Purchase.Parameters.Add("prod_id_in5", MySqlDbType.Int32); Purchase.Parameters.Add("qty_in5", MySqlDbType.Int32);
      Purchase.Parameters.Add("prod_id_in6", MySqlDbType.Int32); Purchase.Parameters.Add("qty_in6", MySqlDbType.Int32);
      Purchase.Parameters.Add("prod_id_in7", MySqlDbType.Int32); Purchase.Parameters.Add("qty_in7", MySqlDbType.Int32);
      Purchase.Parameters.Add("prod_id_in8", MySqlDbType.Int32); Purchase.Parameters.Add("qty_in8", MySqlDbType.Int32);
      Purchase.Parameters.Add("prod_id_in9", MySqlDbType.Int32); Purchase.Parameters.Add("qty_in9", MySqlDbType.Int32);
      Purchase.Parameters.Add(neworder_out_param);

      Browse_by_title = new MySqlCommand("BROWSE_BY_TITLE" + target_store_number, objConn);
      Browse_by_title.CommandType = CommandType.StoredProcedure;
      Browse_by_title.Parameters.Add("batch_size_in", MySqlDbType.Int32);
      Browse_by_title.Parameters.Add("title_in", MySqlDbType.VarChar, 50);

      Browse_by_actor = new MySqlCommand("BROWSE_BY_ACTOR" + target_store_number, objConn);
      Browse_by_actor.CommandType = CommandType.StoredProcedure;
      Browse_by_actor.Parameters.Add("batch_size_in", MySqlDbType.Int32);
      Browse_by_actor.Parameters.Add("actor_in", MySqlDbType.VarChar, 50);

      Browse_by_category = new MySqlCommand("BROWSE_BY_CATEGORY" + target_store_number, objConn);
      Browse_by_category.CommandType = CommandType.StoredProcedure;
      Browse_by_category.Parameters.Add("batch_size_in", MySqlDbType.Int32);
      Browse_by_category.Parameters.Add("category_in", MySqlDbType.VarChar, 50);
      Browse_by_category.Parameters.Add("special_in", MySqlDbType.Int32);

      BrowseReviews_by_actor = new MySqlCommand("GET_PROD_REVIEWS_BY_ACTOR" + target_store_number, objConn);
      BrowseReviews_by_actor.CommandType = CommandType.StoredProcedure;
      BrowseReviews_by_actor.Parameters.Add("actor_in", MySqlDbType.VarChar, 50);
      BrowseReviews_by_actor.Parameters.Add("search_depth_in", MySqlDbType.Int32);

      BrowseReviews_by_title = new MySqlCommand("GET_PROD_REVIEWS_BY_TITLE" + target_store_number, objConn);
      BrowseReviews_by_title.CommandType = CommandType.StoredProcedure;
      BrowseReviews_by_title.Parameters.Add("title_in", MySqlDbType.VarChar, 50);
      BrowseReviews_by_title.Parameters.Add("search_depth_in", MySqlDbType.Int32);

      Get_Prod_Reviews = new MySqlCommand("GET_PROD_REVIEWS" + target_store_number, objConn);
      Get_Prod_Reviews.CommandType = CommandType.StoredProcedure;
      Get_Prod_Reviews.Parameters.Add("batch_size_in", MySqlDbType.Int32);
      Get_Prod_Reviews.Parameters.Add("prod_in", MySqlDbType.Int32);

      Get_Reviews_by_stars = new MySqlCommand("GET_PROD_REVIEWS_BY_STARS" + target_store_number, objConn);
      Get_Reviews_by_stars.CommandType = CommandType.StoredProcedure;
      Get_Reviews_by_stars.Parameters.Add("batch_size_in", MySqlDbType.Int32);
      Get_Reviews_by_stars.Parameters.Add("stars_in", MySqlDbType.Int32);
      Get_Reviews_by_stars.Parameters.Add("prod_in", MySqlDbType.Int32);

      Get_Reviews_by_date = new MySqlCommand("GET_PROD_REVIEWS_BY_DATE" + target_store_number, objConn);
      Get_Reviews_by_date.CommandType = CommandType.StoredProcedure;
      Get_Reviews_by_date.Parameters.Add("batch_size_in", MySqlDbType.Int32);
      Get_Reviews_by_date.Parameters.Add("prod_in", MySqlDbType.Int32);
    }
 
//
//-------------------------------------------------------------------------------------------------
//  
    public bool ds2connect()
    {
      try
      {
        objConn.Open();
      }
      catch (MySqlException e)
      {
        Console.WriteLine("Thread {0}: error in connecting to database {1}: {2}",  Thread.CurrentThread.Name,
          target_server_name , e.Message );
        return(false);
      }

      return(true);
      } // end ds2connect()
 
//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2login(string username_in, string password_in, ref int customerid_out, ref int rows_returned, 
      ref string[] title_out, ref string[] actor_out, ref string[] related_title_out, ref double rt)
      {
      int i_row = 0;
      bool success = true;
      MySqlDataReader Rdr;

      Login.Parameters["username_in"].Value = username_in;
      Login.Parameters["password_in"].Value = password_in;
    
#if (USE_WIN32_TIMER)
      long ctr0 = 0, ctr = 0, freq = 0;
      QueryPerformanceFrequency(ref freq); // obtain system freq (ticks/sec)
      QueryPerformanceCounter(ref ctr0); // Start response time clock   
#else
      TimeSpan TS = new TimeSpan();
      DateTime DT0 = DateTime.Now;
#endif     
    
      try {
        Rdr = Login.ExecuteReader();
        Rdr.Read();
        customerid_out = Rdr.GetInt32(0);

        Rdr.NextResult();

        if (Rdr.HasRows) {
          while (Rdr.Read() && (i_row < GlobalConstants.MAX_ROWS)) {
            title_out[i_row] = Rdr.GetString(0);
            actor_out[i_row] = Rdr.GetString(1);
            related_title_out[i_row] = Rdr.GetString(2);
            ++i_row;
          }
        }

        Rdr.Close();
        rows_returned = i_row;
      } // End try
      catch (MySqlException e) {
        customerid_out = 0;
        Console.WriteLine("Thread {0}: Error in Login: {1}", Thread.CurrentThread.Name, e.Message);
        success = false;
      }

#if (USE_WIN32_TIMER)
      QueryPerformanceCounter(ref ctr); // Stop response time clock
      rt = (ctr - ctr0)/(double) freq; // Calculate response time
#else
      TS = DateTime.Now - DT0;
      rt = TS.TotalSeconds; // Calculate response time
#endif            

      return(success);
      }  // end ds2login
//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2newcustomer(string username_in, string password_in, string firstname_in, 
      string lastname_in, string address1_in, string address2_in, string city_in, string state_in, 
      string zip_in, string country_in, string email_in, string phone_in, int creditcardtype_in, 
      string creditcard_in, int ccexpmon_in, int ccexpyr_in, int age_in, int income_in, 
      string gender_in, ref int customerid_out, ref double rt) 
      {
      int region_in = (country_in == "US") ? 1 : 2;
      string creditcardexpiration_in = String.Format("{0:D4}/{1:D2}", ccexpyr_in, ccexpmon_in);
      bool success = true;

      New_Customer.Parameters["username_in"].Value = username_in;
      New_Customer.Parameters["password_in"].Value = password_in;
      New_Customer.Parameters["firstname_in"].Value = firstname_in;
      New_Customer.Parameters["lastname_in"].Value = lastname_in;
      New_Customer.Parameters["address1_in"].Value = address1_in;
      New_Customer.Parameters["address2_in"].Value = address2_in;
      New_Customer.Parameters["city_in"].Value = city_in;
      New_Customer.Parameters["state_in"].Value = state_in;
      New_Customer.Parameters["zip_in"].Value = (zip_in=="") ? 0 : Convert.ToInt32(zip_in);
      New_Customer.Parameters["country_in"].Value = country_in;
      New_Customer.Parameters["region_in"].Value = region_in;
      New_Customer.Parameters["email_in"].Value = email_in;
      New_Customer.Parameters["phone_in"].Value = phone_in;
      New_Customer.Parameters["creditcardtype_in"].Value = creditcardtype_in;
      New_Customer.Parameters["creditcard_in"].Value = creditcard_in;
      New_Customer.Parameters["creditcardexpiration_in"].Value = creditcardexpiration_in;
      New_Customer.Parameters["age_in"].Value = age_in;
      New_Customer.Parameters["income_in"].Value = income_in;
      New_Customer.Parameters["gender_in"].Value = gender_in;
    
//    Console.WriteLine("Thread {0}: Calling New_Customer w/username_in= {1}  region={2}  ccexp={3}",
//      Thread.CurrentThread.Name, username_in, region_in, creditcardexpiration_in);

#if (USE_WIN32_TIMER)
      long ctr0 = 0, ctr = 0, freq = 0;
      QueryPerformanceFrequency(ref freq); // obtain system freq (ticks/sec)
      QueryPerformanceCounter(ref ctr0); // Start response time clock   
#else
      TimeSpan TS = new TimeSpan();
      DateTime DT0 = DateTime.Now;
#endif

      bool deadlocked = false;      
      do
      {
        try 
          {
          deadlocked = false;
          New_Customer.ExecuteNonQuery();
          }
        catch (MySqlException e) 
          {
          if (e.Number == 1205)
            {
            deadlocked = true;
            int wait = Random.Shared.Next(1000);
            Console.WriteLine("Thread {0}: New_Customer deadlocked...waiting {1} msec, then will retry",Thread.CurrentThread.Name, wait);
            Thread.Sleep(wait); // Wait up to 1 sec, then try again
            }
          else
            {           
            Console.WriteLine("Thread {0}: MySql Error {1} in New_Customer: {2}", 
              Thread.CurrentThread.Name, e.Number, e.Message);
            success = false;
            }
          }
        } while (deadlocked);

        customerid_out = (int) cust_out_param.Value;         
        
#if (USE_WIN32_TIMER)
      QueryPerformanceCounter(ref ctr); // Stop response time clock
      rt = (ctr - ctr0)/(double) freq; // Calculate response time
#else
      TS = DateTime.Now - DT0;
      rt = TS.TotalSeconds; // Calculate response time
#endif        
      return (success);
      } // end ds2newcustomer()

//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2newmember(int customerid_in, int membershiplevel_in, ref int customerid_out, ref double rt)
    {
      bool success = true;

      New_Member.Parameters["customerid_in"].Value = customerid_in;
      New_Member.Parameters["membershiplevel_in"].Value = membershiplevel_in;

#if (USE_WIN32_TIMER)
      long ctr0 = 0, ctr = 0, freq = 0;
      QueryPerformanceFrequency(ref freq); // obtain system freq (ticks/sec)
      QueryPerformanceCounter(ref ctr0); // Start response time clock   
#else
      TimeSpan TS = new TimeSpan();
      DateTime DT0 = DateTime.Now;
#endif

      bool deadlocked = false;
      do
      {
          try
          {
              deadlocked = false;
              New_Member.ExecuteNonQuery();
          }
          catch (MySqlException e)
          {
              if (e.Number == 1205)
              {
                  deadlocked = true;
                  int wait = Random.Shared.Next(1000);
                  Console.WriteLine("Thread {0}: New_Member deadlocked...waiting {1} msec, then will retry",
                    Thread.CurrentThread.Name, wait);
                  Thread.Sleep(wait); // Wait up to 1 sec, then try again
              }
              else
              {
                  Console.WriteLine("Thread {0}: MySql Error {1} in New_Member: {2}",
                    Thread.CurrentThread.Name, e.Number, e.Message);
                  success = false;
              }
          }
      } while (deadlocked);

      customerid_out = (int) member_out_param.Value;

#if (USE_WIN32_TIMER)
      QueryPerformanceCounter(ref ctr); // Stop response time clock
      rt = (ctr - ctr0)/(double) freq; // Calculate response time
#else
      TS = DateTime.Now - DT0;
      rt = TS.TotalSeconds; // Calculate response time
#endif

      //    Console.WriteLine("Thread {0}: New_Customer created w/username_in= {1}  region={2}  customerid={3}",
      //      Thread.CurrentThread.Name, username_in, region_in, customerid_out);

      return (success);
     } // end ds2newmember()

//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2browse(string browse_type_in, string browse_category_in, string browse_actor_in,
      string browse_title_in, int batch_size_in, int search_depth_in, int customerid_out, ref int rows_returned, 
      ref int[] prod_id_out, ref string[] title_out, ref string[] actor_out, ref decimal[] price_out, 
      ref int[] special_out, ref int[] common_prod_id_out, ref double rt)
      {
      int i_row, special = 0;
      bool success = true;
      int[] category_out = new int[GlobalConstants.MAX_ROWS];
      MySqlDataReader Rdr;
  
      // Search for special half the time
      if (Random.Shared.Next(100) < 50) {
        special = 1;
      }

      // Console.WriteLine("Thread {0}: Calling Browse w/ browse_type= {1} batch_size_in= {2}  category= {3}" +
      //   " title= {4}  actor= {5}", Thread.CurrentThread.Name, browse_type_in, batch_size_in, browse_category_in,
      //   browse_title_in, browse_actor_in);
    
      Browse_by_title.Parameters["batch_size_in"].Value = batch_size_in;
      Browse_by_title.Parameters["title_in"].Value = browse_title_in ;

      Browse_by_actor.Parameters["batch_size_in"].Value = batch_size_in;
      Browse_by_actor.Parameters["actor_in"].Value =  browse_actor_in ;

      Browse_by_category.Parameters["batch_size_in"].Value = batch_size_in;
      Browse_by_category.Parameters["category_in"].Value = browse_category_in != "" ? Convert.ToInt32(browse_category_in) : 0 ;
      Browse_by_category.Parameters["special_in"].Value = special;

#if (USE_WIN32_TIMER)
      long ctr0 = 0, ctr = 0, freq = 0;
      QueryPerformanceFrequency(ref freq); // obtain system freq (ticks/sec)
      QueryPerformanceCounter(ref ctr0); // Start response time clock
#else
      TimeSpan TS = new TimeSpan();
      DateTime DT0 = DateTime.Now;
#endif

      try
        {
      	switch(browse_type_in)
        {
           case "title":
             Rdr = Browse_by_title.ExecuteReader();
             break;
           case "actor":
             Rdr = Browse_by_actor.ExecuteReader();
             break;
           case "category":
           default:
             Rdr = Browse_by_category.ExecuteReader();
             break;
        }

        i_row = 0;
        if (Rdr.HasRows)
         {
          while (Rdr.Read())
            {
            prod_id_out[i_row] = Rdr.GetInt32(0);
            category_out[i_row] = Rdr.GetByte(1);
            title_out[i_row] = Rdr.GetString(2);
            actor_out[i_row] = Rdr.GetString(3);
            price_out[i_row] = Rdr.GetDecimal(4);
            special_out[i_row] = Rdr.GetByte(5);
            common_prod_id_out[i_row] = Rdr.GetInt32(6);
            ++i_row;
            }
          }
        Rdr.Close();
        rows_returned = i_row;
        }
      catch (MySqlException e)
        {
        Console.WriteLine("Thread {0}: Error in Browse: {1}", Thread.CurrentThread.Name, e.Message);
        success = false;
        }

#if (USE_WIN32_TIMER)
      QueryPerformanceCounter(ref ctr); // Stop response time clock
      rt = (ctr - ctr0)/(double) freq; // Calculate response time
#else
      TS = DateTime.Now - DT0;
      rt = TS.TotalSeconds; // Calculate response time
#endif

      return success;
      } // end ds2browse()

//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2browsereview(string browse_review_type_in, string get_review_category_in, string get_review_actor_in,
      string get_review_title_in, int batch_size_in, int search_depth_in, int customerid_out, ref int rows_returned,
      ref int[] prod_id_out, ref string[] title_out, ref string[] actor_out, ref int[] review_id_out,
      ref string[] review_date_out, ref int[] review_stars_out, ref int[] review_customerid_out,
      ref string[] review_summary_out, ref string[] review_text_out, ref int[] review_helpfulness_sum_out, ref double rt)
    {
        // Reviews Table: "REVIEW_ID" NUMBER,  "PROD_ID" NUMBER,  "REVIEW_DATE" DATE, "STARS" NUMBER,
        // "CUSTOMERID" NUMBER,  "REVIEW_SUMMARY" VARCHAR2(50 byte), "REVIEW_TEXT" VARCHAR2(1000 byte)
	bool success = true;
        int i_row;
        MySqlDataReader Rdr;

        BrowseReviews_by_actor.Parameters["actor_in"].Value = get_review_actor_in;
        BrowseReviews_by_actor.Parameters["search_depth_in"].Value = search_depth_in ;

        BrowseReviews_by_title.Parameters["title_in"].Value = get_review_title_in;
        BrowseReviews_by_title.Parameters["search_depth_in"].Value = search_depth_in ;

        //    Console.WriteLine("Thread {0}: Calling Browse Review w/ browse_type= {1}  batch_size_in= {2}",  
        //      Thread.CurrentThread.Name, browse_review_type_in, batch_size_in); 

#if (USE_WIN32_TIMER)
      long ctr0 = 0, ctr = 0, freq = 0;
      QueryPerformanceFrequency(ref freq); // obtain system freq (ticks/sec)
      QueryPerformanceCounter(ref ctr0); // Start response time clock   
#else
      TimeSpan TS = new TimeSpan();
      DateTime DT0 = DateTime.Now;
#endif

        try
        {
            switch (browse_review_type_in)
            {
               case "actor":
                  Rdr = BrowseReviews_by_actor.ExecuteReader();
	          break;
	       case "title":
	       default:
                  Rdr = BrowseReviews_by_title.ExecuteReader();
	          break;
	    }

            i_row = 0;
            while (Rdr.Read())
            {
                prod_id_out[i_row] = Rdr.GetInt32(0);
                title_out[i_row] = Rdr.GetString(1);
                actor_out[i_row] = Rdr.GetString(2);
                review_id_out[i_row] = Rdr.GetInt32(3);
                review_date_out[i_row] = Rdr.GetDateTime(4).ToString();
                review_stars_out[i_row] = Rdr.GetInt32(5);
                review_customerid_out[i_row] = Rdr.GetInt32(6);
                review_summary_out[i_row] = Rdr.GetString(7);
                review_text_out[i_row] = Rdr.GetString(8);
                review_helpfulness_sum_out[i_row] = Rdr.GetInt32(9);
                ++i_row;
            } // end while rdr.read()
            Rdr.Close();
            rows_returned = i_row;
          }
        catch (MySqlException e)
        {
            Console.WriteLine("Thread {0}: MySQL Error in Browse Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
            success = false;
        }
        catch (System.Exception e)
        {
            Console.WriteLine("Thread {0}: System Error in Browse Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
            success = false;
        }

#if (USE_WIN32_TIMER)
      QueryPerformanceCounter(ref ctr); // Stop response time clock
      rt = (ctr - ctr0)/(double) freq; // Calculate response time
#else
      TS = DateTime.Now - DT0;
      rt = TS.TotalSeconds; // Calculate response time
#endif

       return (success);
    } // end ds2browsereview()

//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2getreview(string get_review_type_in, int get_review_prod_in, int get_review_stars_in, int customerid_out, int batch_size_in, ref int rows_returned,
      ref int[] prod_id_out, ref int[] review_id_out, ref string[] review_date_out, ref int[] review_stars_out, ref int[] review_customerid_out,
      ref string[] review_summary_out, ref string[] review_text_out, ref int[] review_helpfulness_sum_out, ref double rt)
    {
        // Reviews Table: "REVIEW_ID" NUMBER,  "PROD_ID" NUMBER,  "REVIEW_DATE" DATE, "STARS" NUMBER,
        // "CUSTOMERID" NUMBER,  "REVIEW_SUMMARY" VARCHAR2(50 byte), "REVIEW_TEXT" VARCHAR2(1000 byte) 
        int i_row;
	bool success = true;
        MySqlDataReader Rdr;

        switch (get_review_type_in)
        {
            case "noorder":
	    default:
                Get_Prod_Reviews.Parameters["batch_size_in"].Value = batch_size_in;
                Get_Prod_Reviews.Parameters["prod_in"].Value = get_review_prod_in ;
                break;
            case "star":
                Get_Reviews_by_stars.Parameters["batch_size_in"].Value = batch_size_in;
                Get_Reviews_by_stars.Parameters["stars_in"].Value = get_review_stars_in;
                Get_Reviews_by_stars.Parameters["prod_in"].Value = get_review_prod_in ;
                break;
            case "date":
                Get_Reviews_by_date.Parameters["batch_size_in"].Value = batch_size_in;
                Get_Reviews_by_date.Parameters["prod_in"].Value = get_review_prod_in ;
                break;
        }
                
#if (USE_WIN32_TIMER)
      long ctr0 = 0, ctr = 0, freq = 0;
      QueryPerformanceFrequency(ref freq); // obtain system freq (ticks/sec)
      QueryPerformanceCounter(ref ctr0); // Start response time clock   
#else
      TimeSpan TS = new TimeSpan();
      DateTime DT0 = DateTime.Now;
#endif

        try
        {
	    switch (get_review_type_in)
	    {
		case "noorder":
		default:
            	   Rdr = Get_Prod_Reviews.ExecuteReader();
		   break;
		case "star":
            	   Rdr = Get_Reviews_by_stars.ExecuteReader();
		   break;
		case "date":
            	   Rdr = Get_Reviews_by_date.ExecuteReader();
		   break;
	    }

            i_row = 0;
            while (Rdr.Read())
            {
                review_id_out[i_row] = Rdr.GetInt32(0);
                prod_id_out[i_row] = Rdr.GetInt32(1);
                review_date_out[i_row] = Rdr.GetDateTime(2).ToString();
                review_stars_out[i_row] = Rdr.GetInt32(3);
                review_customerid_out[i_row] = Rdr.GetInt32(4);
                review_summary_out[i_row] = Rdr.GetString(5);
                review_text_out[i_row] = Rdr.GetString(6);
                review_helpfulness_sum_out[i_row] = Rdr.GetInt32(7);
//Console.WriteLine("\tprod_id_out: {0} review_id_out: {1} review_date_out: {2} review_stars_out: {3} review_customerid_out: {4} review_summary_out: {5} review_text_out: {6} review_helpfulness_sum_out: {7}\n", prod_id_out[i_row], review_id_out[i_row], review_date_out[i_row], review_stars_out[i_row], review_customerid_out[i_row], review_summary_out[i_row], review_text_out[i_row], review_helpfulness_sum_out[i_row] );
                ++i_row;
            } // end while rdr.read()
            Rdr.Close();
            rows_returned = i_row;
        }
        catch (MySqlException e)
        {
            Console.WriteLine("Thread {0}: MySQL Error in Get Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
            success = false;
        }
        catch (System.Exception e)
        {
            Console.WriteLine("Thread {0}: System Error in Get Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
            success = false;
        }

#if (USE_WIN32_TIMER)
      QueryPerformanceCounter(ref ctr); // Stop response time clock
      rt = (ctr - ctr0)/(double) freq; // Calculate response time
#else
      TS = DateTime.Now - DT0;
      rt = TS.TotalSeconds; // Calculate response time
#endif
                       
      return (success);
    } // end ds2getreview()

//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2newreview(int new_review_prod_id_in, int new_review_stars_in, int new_review_customerid_in,
            string new_review_summary_in, string new_review_text_in, ref int newreviewid_out, ref double rt)
    {
      bool success = true; 

      New_Review.Parameters["prod_id_in"].Value = new_review_prod_id_in;
      New_Review.Parameters["stars_in"].Value = new_review_stars_in;
      New_Review.Parameters["customerid_in"].Value = new_review_customerid_in;
      New_Review.Parameters["review_summary_in"].Value = new_review_summary_in;
      New_Review.Parameters["review_text_in"].Value = new_review_text_in;

      bool deadlocked = false;

#if (USE_WIN32_TIMER)
      long ctr0 = 0, ctr = 0, freq = 0;
      QueryPerformanceFrequency(ref freq); // obtain system freq (ticks/sec)
      QueryPerformanceCounter(ref ctr0); // Start response time clock   
#else
      TimeSpan TS = new TimeSpan();
      DateTime DT0 = DateTime.Now;
#endif

      do
      {
          try
          {
              deadlocked = false;
              New_Review.ExecuteNonQuery();
          }
          catch (MySqlException e)
          {
              if (e.Number == 1205)
              {
                  deadlocked = true;
                  int wait = Random.Shared.Next(1000);
                  Console.WriteLine("Thread {0}: New_Review deadlocked...waiting {1} msec, then will retry",
                    Thread.CurrentThread.Name, wait);
                  Thread.Sleep(wait); // Wait up to 1 sec, then try again
              }
              else
              {
                  Console.WriteLine("Thread {0}: MySql Error {1} in New_Review: {2}",
                    Thread.CurrentThread.Name, e.Number, e.Message);
                  success = false;
              }
          }
      } while (deadlocked);

      newreviewid_out = (int)reviewid_out_param.Value;   

#if (USE_WIN32_TIMER)
      QueryPerformanceCounter(ref ctr); // Stop response time clock
      rt = (ctr - ctr0)/(double) freq; // Calculate response time
#else
      TS = DateTime.Now - DT0;
      rt = TS.TotalSeconds; // Calculate response time
#endif
      return (success);
    } // end ds2newreview()

//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2newreviewhelpfulness(int reviewid_in, int customerid_in, int reviewhelpfulness_in, ref int reviewhelpfulnessid_out, ref double rt)
    {
      bool success = true;

      New_Helpfulness.Parameters["review_id_in"].Value = reviewid_in;
      New_Helpfulness.Parameters["customerid_in"].Value = customerid_in;
      New_Helpfulness.Parameters["review_helpfulness_in"].Value = reviewhelpfulness_in;

      bool deadlocked = false;

#if (USE_WIN32_TIMER)
      long ctr0 = 0, ctr = 0, freq = 0;
      QueryPerformanceFrequency(ref freq); // obtain system freq (ticks/sec)
      QueryPerformanceCounter(ref ctr0); // Start response time clock   
#else
      TimeSpan TS = new TimeSpan();
      DateTime DT0 = DateTime.Now;
#endif

      do
      {
          try
          {
              deadlocked = false;
              New_Helpfulness.ExecuteNonQuery();
          }
          catch (MySqlException e)
          {
              if (e.Number == 1205)
              {
                  deadlocked = true;
                  int wait = Random.Shared.Next(1000);
                  Console.WriteLine("Thread {0}: New_Helpfulness deadlocked...waiting {1} msec, then will retry",
                    Thread.CurrentThread.Name, wait);
                  Thread.Sleep(wait); // Wait up to 1 sec, then try again
              }
              else
              {
                  Console.WriteLine("Thread {0}: MySql Error {1} in New_Helpfulness: {2}",
                    Thread.CurrentThread.Name, e.Number, e.Message);
                  success = false;
              }
          }
      } while (deadlocked);

      reviewhelpfulnessid_out = (int)helpfulnessid_out_param.Value;   

#if (USE_WIN32_TIMER)
      QueryPerformanceCounter(ref ctr); // Stop response time clock
      rt = (ctr - ctr0)/(double) freq; // Calculate response time
#else
      TS = DateTime.Now - DT0;
      rt = TS.TotalSeconds; // Calculate response time
#endif

      return (success);
    } // end ds2newreviewhelpfulness()

//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2purchase(int cart_items, int[] prod_id_in, int[] qty_in, int customerid_out,
      ref int neworderid_out, ref bool IsRollback, ref double rt)
      {
      int i, j;
      bool success = true;
      bool deadlocked = false;
      MySqlDataReader Rdr;
      
      // Find total cost of purchase
      Decimal netamount_in = 0;

      string db_query = "select PROD_ID, PRICE from PRODUCTS" + target_store_number + " where PROD_ID in (" + prod_id_in[0];

      for (i=1; i<cart_items; i++) {
         db_query = db_query + "," + prod_id_in[i];
      }

      db_query = db_query + ")";

      // Console.WriteLine(db_query);
      
      MySqlCommand cost_command = new MySqlCommand(db_query, objConn);
      Rdr = cost_command.ExecuteReader();
      while (Rdr.Read()) {
        j = 0;
        int prod_id = Rdr.GetInt32(0);
        while (prod_id_in[j] != prod_id) ++j; // Find which product was returned
        netamount_in = netamount_in + qty_in[j] * Rdr.GetDecimal(1);
        // Console.WriteLine(j + " " + prod_id + " " + Rdr.GetDecimal(1));
      }
      Rdr.Close();

      Decimal taxamount_in =  (Decimal) 0.0825 * netamount_in;
      Decimal totalamount_in = netamount_in + taxamount_in;

      // Console.WriteLine("Thread {0}: Calling Purchase w/ customerid = {1}  number_items= {2} taxamount_in= {3} totalamount_in= {4}",  
      //   Thread.CurrentThread.Name, customerid_out, cart_items, taxamount_in, totalamount_in);

      Purchase.Parameters["customerid_in"].Value = customerid_out;
      Purchase.Parameters["number_items"].Value = cart_items;
      Purchase.Parameters["netamount_in"].Value = netamount_in;
      Purchase.Parameters["taxamount_in"].Value = taxamount_in;
      Purchase.Parameters["totalamount_in"].Value = totalamount_in;
      Purchase.Parameters["prod_id_in0"].Value = prod_id_in[0]; Purchase.Parameters["qty_in0"].Value = qty_in[0];
      Purchase.Parameters["prod_id_in1"].Value = prod_id_in[1]; Purchase.Parameters["qty_in1"].Value = qty_in[1];
      Purchase.Parameters["prod_id_in2"].Value = prod_id_in[2]; Purchase.Parameters["qty_in2"].Value = qty_in[2];
      Purchase.Parameters["prod_id_in3"].Value = prod_id_in[3]; Purchase.Parameters["qty_in3"].Value = qty_in[3];
      Purchase.Parameters["prod_id_in4"].Value = prod_id_in[4]; Purchase.Parameters["qty_in4"].Value = qty_in[4];
      Purchase.Parameters["prod_id_in5"].Value = prod_id_in[5]; Purchase.Parameters["qty_in5"].Value = qty_in[5];
      Purchase.Parameters["prod_id_in6"].Value = prod_id_in[6]; Purchase.Parameters["qty_in6"].Value = qty_in[6];
      Purchase.Parameters["prod_id_in7"].Value = prod_id_in[7]; Purchase.Parameters["qty_in7"].Value = qty_in[7];
      Purchase.Parameters["prod_id_in8"].Value = prod_id_in[8]; Purchase.Parameters["qty_in8"].Value = qty_in[8];
      Purchase.Parameters["prod_id_in9"].Value = prod_id_in[9]; Purchase.Parameters["qty_in9"].Value = qty_in[9];

#if (USE_WIN32_TIMER)
      long ctr0 = 0, ctr = 0, freq = 0;
      QueryPerformanceFrequency(ref freq); // obtain system freq (ticks/sec)  
      QueryPerformanceCounter(ref ctr0); // Start response time clock   
#else
      TimeSpan TS = new TimeSpan();
      DateTime DT0 = DateTime.Now;
#endif

      do {
        try {
          deadlocked = false;
          Purchase.ExecuteScalar();
          neworderid_out = (int)neworder_out_param.Value;
          // Console.WriteLine("neworderid_out= {0}",neworderid_out);
        }  // End Try
        catch (MySqlException myException) {
          if (myException.Message.Contains("deadlock")) {
            deadlocked = true;
            int wait = Random.Shared.Next(1000);
            Thread.Sleep(wait); // Wait up to 1 sec, then try again
            Console.WriteLine("Thread {0}: Purchase deadlocked...waiting {1} msec, then will retry", Thread.CurrentThread.Name, wait);
          }
          else {
            Console.WriteLine("Thread {0}: Error in Purchase: {1}", Thread.CurrentThread.Name, myException.Message);
            success = false;
          }
        } // End Catch
      } while (deadlocked);

#if (USE_WIN32_TIMER)
      QueryPerformanceCounter(ref ctr); // Stop response time clock
      rt = (ctr - ctr0)/(double) freq; // Calculate response time
#else
      TS = DateTime.Now - DT0;
      rt = TS.TotalSeconds; // Calculate response time
#endif

      if (neworderid_out == 0) {
        IsRollback = true;
        //      Console.WriteLine("Thread {0}: Purchase: Insufficient stock for order {1} - order not processed",
        //        Thread.CurrentThread.Name, neworderid_out);
      }

      return(success);
      } // end ds2purchase()
    
//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2close()
      {
      objConn.Close();   
      return(true);   
      } // end ds2close()
    } // end Class ds2Interface
  } // end namespace ds2xdriver
  
        
